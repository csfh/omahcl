require "test_helper"
require "tmpdir"
require "fileutils"
require "json"
require "open3"

class CollectorTest < ActiveSupport::TestCase
  SECURE_BOOT_VAR = "sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c".freeze

  setup do
    @root = Dir.mktmpdir("omahcl-sys")
    @bin = Dir.mktmpdir("omahcl-bin")
    write("etc/os-release", <<~OS)
      NAME="Omarchy"
      ID=omarchy
      VERSION_ID="4.0.2"
    OS
    write("etc/pacman.conf", <<~CONF)
      [core]
      Include = /etc/pacman.d/mirrorlist
      [omarchy]
      Server = https://pkgs.omarchy.org/stable/$arch
    CONF
    write("sys/class/dmi/id/sys_vendor", "LENOVO")
    write("sys/class/dmi/id/product_name", "ThinkPad X220")
    write("sys/class/dmi/id/product_family", "ThinkPad X220")
    write("sys/class/dmi/id/chassis_type", "10")
    write("etc/machine-id", "0123456789abcdef0123456789abcdef")
    write("sys/class/dmi/id/product_serial", "SHOULD-NOT-BE-READ")
    write("sys/class/dmi/id/board_serial", "BOARD-SERIAL")
    write("proc/cpuinfo", "processor\t: 0\nvendor_id\t: GenuineIntel\nmodel name\t: Intel Core i5-2520M\n")
    write("proc/meminfo", "MemTotal:        8192000 kB\n")
    write("proc/version", "Linux version 6.9.0-arch1 (gcc)\n")
    FileUtils.mkdir_p(File.join(@root, "sys/firmware/efi"))
    secure_boot(:off)
  end

  teardown do
    FileUtils.remove_entry(@root)
    FileUtils.remove_entry(@bin)
  end

  test "on omarchy a dry run emits allowlisted json without serials" do
    status, output = run_collector("OMAHCL_DRY_RUN" => "1")
    payload = JSON.parse(output)

    assert_equal 0, status
    assert_equal "4.0.2", payload.dig("omarchy", "version")
    assert_equal "stable", payload.dig("omarchy", "channel")
    assert_equal "LENOVO", payload.dig("hardware", "vendor")
    assert_equal "ThinkPad X220", payload.dig("hardware", "product")
    assert_match(/\A[a-f0-9]{64}\z/, payload["instance_digest"])
    assert_nil payload["source"]
    dumped = JSON.generate(payload)
    refute_includes dumped, "SHOULD-NOT-BE-READ"
    refute_includes dumped, "BOARD-SERIAL"
    refute_includes dumped.downcase, "serial"
    source = File.read(Rails.root.join("lib/collectors/omarchy.sh"))
    refute_includes source, "omarchy-channel-current"
  end

  test "on omarchy the channel comes from the package repository" do
    write("etc/pacman.conf", "[omarchy]\nServer = https://pkgs.omarchy.org/edge/$arch\n")

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    assert_equal "edge", JSON.parse(output).dig("omarchy", "channel")
  end

  test "the omarchy payload passes the server sanitizer" do
    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    attrs = ReportSanitizer.clean!(JSON.parse(output))

    assert_equal "ThinkPad X220", attrs[:product]
    assert_equal "4.0.2", attrs[:omarchy_version]
  end

  test "memory is rounded to the nearest gigabyte" do
    write("proc/meminfo", "MemTotal:        8000000 kB\n")

    _status, output = run_collector("OMAHCL_SUBMIT" => "no")

    assert_includes output, "8 GB memory"
  end

  test "the instance digest is pinned so a rename cannot split existing machines" do
    _status, omarchy = run_collector("OMAHCL_DRY_RUN" => "1")

    # Serials are root-only on a real machine and never feed the digest, so this is
    # the value every machine had before they were dropped from the formula. The
    # serial fixtures in setup stay readable to prove they are ignored.
    assert_equal "88c68e85e1b0276e7cd71f109df70d796ceea8ee464a18b88c664e25e0eb932f", JSON.parse(omarchy)["instance_digest"]
  end

  test "on omarchy secure boot, a tpm and uefi show in the payload" do
    secure_boot(:on)
    FileUtils.mkdir_p(File.join(@root, "sys/class/tpm"))

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")
    hardware = JSON.parse(output)["hardware"]

    assert_equal true, hardware.dig("secure_boot", "enabled")
    assert_equal true, hardware.dig("tpm", "present")
    assert_equal true, hardware["uefi"]
  end

  test "on omarchy the gpus come from lspci" do
    fake_lspci(<<~LSPCI)
      00:02.0 "VGA compatible controller" "NVIDIA Corporation" "GA106 [GeForce RTX 3060]" -ra1
    LSPCI

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_SKIP_CMDS" => nil)

    assert_includes JSON.parse(output).dig("hardware", "gpus"), { "vendor" => "NVIDIA Corporation", "name" => "GA106 [GeForce RTX 3060]" }
  end

  test "an Apple Silicon Mac under Asahi reports from the device tree, with its M-series chip" do
    asahi!("Apple MacBook Air (13-inch, M2, 2022)", "apple,j413", "apple,t8112")

    status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")
    hardware = JSON.parse(output)["hardware"]

    assert_equal 0, status
    assert_equal "Apple", hardware["vendor"]
    assert_equal "MacBook Air (13-inch, M2, 2022)", hardware["product"]
    assert_equal "10", hardware["chassis"]
    assert_equal({ "model" => "Apple M2", "vendor" => "Apple", "arch" => "aarch64", "cores" => 8 }, hardware["cpu"])
    assert_equal [ { "vendor" => "Apple", "name" => "Apple M2 GPU" } ], hardware["gpus"]
    ReportSanitizer.clean!(JSON.parse(output))
  end

  test "every Apple SoC id in the device tree names its chip" do
    {
      "t8103" => "Apple M1", "t6000" => "Apple M1 Pro", "t6001" => "Apple M1 Max", "t6002" => "Apple M1 Ultra",
      "t8112" => "Apple M2", "t6020" => "Apple M2 Pro", "t6021" => "Apple M2 Max", "t6022" => "Apple M2 Ultra",
      "t8122" => "Apple M3", "t6030" => "Apple M3 Pro", "t6031" => "Apple M3 Max", "t6034" => "Apple M3 Max",
      "t6032" => "Apple M3 Ultra", "t8132" => "Apple M4", "t8140" => "Apple A18 Pro"
    }.each do |soc, chip|
      asahi!("Apple Mac mini (#{chip.delete_prefix('Apple ')}, 2024)", "apple,j000", "apple,#{soc}")

      _status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")

      assert_equal chip, JSON.parse(output).dig("hardware", "cpu", "model"), soc
      assert_equal "35", JSON.parse(output).dig("hardware", "chassis")
    end
  end

  test "an Apple Silicon digest hashes the machine without the chip name, and delete rebuilds it" do
    asahi!("Apple MacBook Air (13-inch, M2, 2022)", "apple,j413", "apple,t8112")
    expected = Digest::SHA256.hexdigest([ "omarchy-market-instance-v1", "0123456789abcdef0123456789abcdef", "Apple", "MacBook Air (13-inch, M2, 2022)", "Unknown CPU" ].join("\0"))

    _status, collected = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")
    _status, deleted = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")

    assert_equal expected, JSON.parse(collected)["instance_digest"]
    assert_equal({ "instance_digest" => expected }, JSON.parse(deleted))
  end

  test "an Arm machine with DMI gets core names from lscpu without changing its digest" do
    write("proc/cpuinfo", "processor\t: 0\nCPU part\t: 0xd85\n")
    legacy = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64").last
    fake_lscpu(<<~LSCPU)
      Architecture:                         aarch64
      Vendor ID:                            ARM
        Model name:                         Cortex-A725
        Thread(s) per core:                 1
        Model name:                         Cortex-X925
        Model name:                         -
        Model name:                         Cortex-A725
    LSCPU
    fake_lspci("")

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_SKIP_CMDS" => nil, "OMAHCL_ARCH" => "aarch64")

    assert_equal "Unknown CPU", JSON.parse(legacy).dig("hardware", "cpu", "model")
    assert_equal "Cortex-A725 + Cortex-X925", JSON.parse(output).dig("hardware", "cpu", "model")
    assert_equal JSON.parse(legacy)["instance_digest"], JSON.parse(output)["instance_digest"]
  end

  test "partial DMI does not stop an Apple Silicon Mac from using its device tree" do
    asahi!("Apple Mac mini (M1, 2020)", "apple,j274", "apple,t8103")
    write("sys/class/dmi/id/sys_vendor", "Apple Inc.")

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")
    hardware = JSON.parse(output)["hardware"]

    assert_equal "Apple", hardware["vendor"]
    assert_equal "Mac mini (M1, 2020)", hardware["product"]
    assert_equal "Apple M1", hardware.dig("cpu", "model")
  end

  test "without DMI or an Apple device tree the collector still has no machine to report" do
    FileUtils.rm_rf(File.join(@root, "sys/class/dmi"))
    write("proc/device-tree/model", "Raspberry Pi 5 Model B\0")
    write("proc/device-tree/compatible", "raspberrypi,5-model-b\0brcm,bcm2712\0")

    status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")

    assert_equal 1, status
    assert_includes output, "Could not read machine vendor and product from DMI or the device tree"
  end

  test "off omarchy the script says so, sends nothing and exits non-zero, even with a yes" do
    leave_omarchy
    fake_curl

    status, output = run_collector("OMAHCL_SUBMIT" => "yes")

    assert_equal 2, status
    assert_includes output, "not running Omarchy"
    assert_includes output, "sent nothing"
    refute_includes output, "Verdict"
    assert_empty curl_calls
  end

  test "on omarchy sends nothing when the person declines" do
    status, output = run_collector("OMAHCL_SUBMIT" => "no")

    assert_equal 0, status
    assert_includes output, "LENOVO ThinkPad X220"
    assert_includes output, "Nothing was sent."
    refute_includes output, "Could not reach"
  end

  test "on omarchy sends nothing without a terminal to ask on" do
    skip "setsid is not available" unless system("command -v setsid >/dev/null 2>&1")

    status, output = run_collector({}, true)

    assert_equal 0, status
    assert_includes output, "Run this in a terminal"
    refute_includes output, "Could not reach"
  end

  test "on omarchy sends only after a yes" do
    status, output = run_collector("OMAHCL_SUBMIT" => "yes")

    refute_equal 0, status
    assert_includes output, "Could not reach Omarchy HCL"
  end

  test "on omarchy the notice explains the privacy policy and links to it before asking" do
    _status, output = run_collector("OMAHCL_SUBMIT" => "no")

    assert_includes output, "Privacy policy: http://example.test/privacy"
    assert_includes output, "a one-way hash of the machine-id, model and CPU"
    assert_includes output, "never sends serial numbers, MAC addresses, your hostname or username"
    assert_includes output, "stores no IP address with the report"
    assert_includes output, "The report is public."
    refute_match(/candidate/i, output)
  end

  test "macos is not an omarchy machine and sends nothing" do
    fake_curl

    status, output = run_collector("OMAHCL_KERNEL" => "Darwin", "OMAHCL_ARCH" => "arm64", "OMAHCL_SUBMIT" => "yes")

    assert_equal 2, status
    assert_includes output, "only reports machines running Omarchy"
    assert_empty curl_calls
  end

  test "an unsupported kernel exits cleanly" do
    status, output = run_collector("OMAHCL_KERNEL" => "FreeBSD")

    assert_equal 2, status
    assert_includes output, "only runs on Linux"
  end

  test "missing proc and sys exits cleanly" do
    FileUtils.rm_rf(File.join(@root, "proc"))

    status, output = run_collector

    assert_equal 2, status
    assert_includes output, "Could not read /proc and /sys"
  end

  test "delete rebuilds exactly the digest the collector sends, on omarchy and off it" do
    _status, collected = run_collector("OMAHCL_DRY_RUN" => "1")
    expected = JSON.parse(collected)["instance_digest"]

    [ true, false ].each do |on_omarchy|
      leave_omarchy unless on_omarchy
      status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_DRY_RUN" => "1")

      assert_equal 0, status
      assert_equal({ "instance_digest" => expected }, JSON.parse(output), "on_omarchy=#{on_omarchy}")
    end
  end

  test "delete sends nothing when the person declines" do
    fake_curl

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_SUBMIT" => "no")

    assert_equal 0, status
    assert_includes output, "Nothing was sent."
    assert_includes output, "Privacy policy: http://example.test/privacy"
    assert_includes output, "Database backups keep a deleted report for up to a day"
    assert_empty curl_calls
  end

  test "delete sends nothing without a terminal to ask on" do
    skip "setsid is not available" unless system("command -v setsid >/dev/null 2>&1")
    fake_curl

    status, output = run_collector({ "OMAHCL_ACTION" => "delete" }, true)

    assert_equal 0, status
    assert_includes output, "Run this in a terminal to choose whether to delete it"
    assert_empty curl_calls
  end

  test "delete posts the digest with a nonce after a yes" do
    fake_curl(deletions: '{"deleted":2}')

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_SUBMIT" => "yes")

    assert_equal 0, status
    assert_includes output, "Deleted 2 report(s) for this machine."
    post = curl_calls.find { |call| call.include?("/deletions") }
    assert_includes post, "http://example.test/deletions"
    body = JSON.parse(post[/-d (\{.*\}) http/, 1])
    assert_equal [ "instance_digest", "nonce" ], body.keys
    assert_equal "test-nonce", body["nonce"]
    assert_match(/\A\h{64}\z/, body["instance_digest"])
    refute_includes post, "0123456789abcdef"
  end

  test "delete says why nothing matched and still exits cleanly" do
    fake_curl(deletions: '{"deleted":0}')

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_SUBMIT" => "yes")

    assert_equal 0, status
    assert_includes output, "No report matched this machine"
    assert_includes output, "reinstall"
  end

  test "delete exits non-zero when the server rejects the request" do
    fake_curl(deletions: "", deletions_exit: 22)

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_SUBMIT" => "yes")

    refute_equal 0, status
    assert_includes output, "rejected the deletion request"
    refute_includes output, "Deleted"
  end

  test "delete exits non-zero when the site cannot be reached for a challenge" do
    fake_curl(challenge_exit: 7)

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_SUBMIT" => "yes")

    refute_equal 0, status
    assert_includes output, "Could not reach Omarchy HCL"
  end

  test "delete with no dmi has no report to find" do
    FileUtils.rm_rf(File.join(@root, "sys/class/dmi"))
    fake_curl

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_SUBMIT" => "yes")

    assert_equal 1, status
    assert_includes output, "cannot be found"
    assert_empty curl_calls
  end

  test "delete on macos sends nothing" do
    fake_curl

    status, output = run_collector("OMAHCL_ACTION" => "delete", "OMAHCL_KERNEL" => "Darwin", "OMAHCL_SUBMIT" => "yes")

    assert_equal 0, status
    assert_includes output, "never sent a report to delete"
    assert_empty curl_calls
  end

  test "an unsubstituted action collects" do
    status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    assert_equal 0, status
    assert JSON.parse(output).key?("omarchy")
  end

  test "wsl is detected" do
    leave_omarchy
    write("proc/version", "Linux version 5.15.0-microsoft-standard-WSL2\n")

    status, output = run_collector

    assert_equal 2, status
    assert_includes output, "Windows Subsystem for Linux"
  end

  private
    def leave_omarchy
      write("etc/os-release", "NAME=\"Arch Linux\"\nID=arch\n")
    end

    # A curl that records each call and answers like the site. A failing exit code
    # stands for curl -f seeing an HTTP error.
    def fake_curl(deletions: '{"deleted":1}', deletions_exit: 0, challenge_exit: 0)
      File.write(File.join(@bin, "curl"), <<~SH)
        #!/bin/sh
        echo "$@" >> "#{curl_log}"
        case "$*" in
          */challenges*) printf '{"nonce":"test-nonce"}'; exit #{challenge_exit} ;;
          */deletions*) printf '%s' '#{deletions}'; exit #{deletions_exit} ;;
        esac
      SH
      File.chmod(0o755, File.join(@bin, "curl"))
    end

    def curl_log = File.join(@bin, "curl.log")

    def curl_calls
      File.exist?(curl_log) ? File.readlines(curl_log, chomp: true) : []
    end

    def secure_boot(state)
      path = File.join(@root, SECURE_BOOT_VAR)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, [ 6, 0, 0, 0, state == :on ? 1 : 0 ].pack("C*"))
    end

    def fake_lspci(output)
      path = File.join(@bin, "lspci")
      File.write(path, "#!/bin/sh\ncat <<'EOF'\n#{output}EOF\n")
      File.chmod(0o755, path)
    end

    # A Mac under Asahi Linux: no DMI, a device tree, and an /proc/cpuinfo without a
    # `model name`.
    def asahi!(model, *compatible)
      FileUtils.rm_rf(File.join(@root, "sys/class/dmi"))
      write("proc/device-tree/model", "#{model}\0")
      write("proc/device-tree/compatible", compatible.join("\0") + "\0apple,arm-platform\0")
      write("proc/cpuinfo", (0...8).map { |n| "processor\t: #{n}\nBogoMIPS\t: 48.00\nCPU part\t: 0x033\n\n" }.join)
    end

    def fake_lscpu(output)
      path = File.join(@bin, "lscpu")
      File.write(path, "#!/bin/sh\ncat <<'EOF'\n#{output}EOF\n")
      File.chmod(0o755, path)
    end

    def write(relative, content)
      path = File.join(@root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    def run_collector(extra = {}, detach = false)
      env = {
        "OMAHCL_SYS_ROOT" => @root,
        "OMAHCL_URL" => "http://example.test",
        "OMAHCL_SKIP_CMDS" => "1",
        "OMAHCL_ARCH" => "x86_64",
        "PATH" => "#{@bin}:#{ENV['PATH']}"
      }.merge(extra)
      script = Rails.root.join("lib/collectors/omarchy.sh").to_s
      command = detach ? [ "setsid", "-w", "bash", script ] : [ "bash", script ]
      output, status = Open3.capture2e(env, *command, stdin_data: "")
      [ status.exitstatus, output ]
    end
end
