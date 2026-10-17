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

    assert_equal "omarchy", attrs[:source]
    assert_equal "ThinkPad X220", attrs[:product]
  end

  test "memory is rounded to the nearest gigabyte" do
    leave_omarchy
    write("proc/meminfo", "MemTotal:        8000000 kB\n")

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    assert_includes output, "8 GB memory"
  end

  test "instance digests are pinned so a rename cannot split existing machines" do
    _status, omarchy = run_collector("OMAHCL_DRY_RUN" => "1")
    leave_omarchy
    _status, candidate = run_collector("OMAHCL_DRY_RUN" => "1")

    expected_omarchy = Digest::SHA256.hexdigest("omarchy-market-instance-v1\0" + "0123456789abcdef0123456789abcdef\0SHOULD-NOT-BE-READ\0BOARD-SERIAL")
    expected_candidate = Digest::SHA256.hexdigest("omarchy-market-candidate-v1\0" + "0123456789abcdef0123456789abcdef\0SHOULD-NOT-BE-READ\0BOARD-SERIAL")
    assert_equal expected_omarchy, JSON.parse(omarchy)["instance_digest"]
    assert_equal expected_candidate, JSON.parse(candidate.lines.last)["instance_digest"]
  end

  test "off omarchy a clean machine is likely and the dry run is a candidate payload" do
    leave_omarchy

    status, output = run_collector("OMAHCL_DRY_RUN" => "1")
    payload = JSON.parse(output.lines.last)

    assert_equal 0, status
    assert_includes output, "Verdict: likely."
    assert_equal "candidate", payload["source"]
    assert_equal "likely", payload["verdict"]
    assert_equal "arch", payload["host_os"]
    assert_nil payload["omarchy"]
    refute_includes JSON.generate(payload).downcase, "serial"
  end

  test "the candidate payload passes the server sanitizer" do
    leave_omarchy

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")
    attrs = ReportSanitizer.clean!(JSON.parse(output.lines.last))

    assert_equal "candidate", attrs[:source]
    assert_equal "likely", attrs[:verdict]
    assert_nil attrs[:omarchy_version]
  end

  test "candidate and omarchy digests differ for the same machine" do
    _status, omarchy = run_collector("OMAHCL_DRY_RUN" => "1")
    leave_omarchy
    _status, candidate = run_collector("OMAHCL_DRY_RUN" => "1")

    refute_equal JSON.parse(omarchy)["instance_digest"], JSON.parse(candidate.lines.last)["instance_digest"]
  end

  test "off omarchy secure boot on is a fix, not a blocker" do
    leave_omarchy
    secure_boot(:on)

    status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    assert_equal 0, status
    assert_includes output, "Verdict: likely, once you change the BIOS settings below."
    assert_includes output, "Secure Boot is on"
    assert_equal "likely", JSON.parse(output.lines.last)["verdict"]
  end

  test "off omarchy an unreadable secure boot state is unclear" do
    leave_omarchy
    FileUtils.rm(File.join(@root, SECURE_BOOT_VAR))

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    assert_includes output, "Verdict: unclear."
    assert_includes output, "Could not read the Secure Boot state"
  end

  test "off omarchy an nvidia gpu is unclear and says to verify" do
    leave_omarchy
    fake_lspci(<<~LSPCI)
      00:02.0 "VGA compatible controller" "NVIDIA Corporation" "GA106 [GeForce RTX 3060]" -ra1
    LSPCI

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_SKIP_CMDS" => nil)

    assert_includes output, "Verdict: unclear."
    assert_includes output, "NVIDIA GPU"
    assert_includes output, "(to verify)"
    assert_includes output, %("name":"GA106 [GeForce RTX 3060]")
  end

  test "off omarchy an apple silicon machine is unlikely" do
    leave_omarchy
    write("sys/class/dmi/id/sys_vendor", "Apple Inc.")

    status, output = run_collector("OMAHCL_DRY_RUN" => "1", "OMAHCL_ARCH" => "aarch64")

    assert_equal 0, status
    assert_includes output, "Verdict: unlikely."
    assert_includes output, "not supported"
    assert_equal "unlikely", JSON.parse(output.lines.last)["verdict"]
  end

  test "off omarchy a tpm is a change to make before installing" do
    leave_omarchy
    FileUtils.mkdir_p(File.join(@root, "sys/class/tpm"))

    _status, output = run_collector("OMAHCL_DRY_RUN" => "1")

    assert_includes output, "A TPM is visible"
    assert_includes output, "Verdict: likely, once you change the BIOS settings below."
  end

  test "off omarchy a machine without dmi has nothing to share" do
    leave_omarchy
    FileUtils.rm_rf(File.join(@root, "sys/class/dmi"))

    status, output = run_collector("OMAHCL_SUBMIT" => "yes")

    assert_equal 0, status
    assert_includes output, "nothing to share"
    refute_includes output, "Could not reach"
  end

  test "off omarchy sends nothing when the person declines" do
    leave_omarchy

    status, output = run_collector("OMAHCL_SUBMIT" => "no")

    assert_equal 0, status
    assert_includes output, "Verdict:"
    refute_includes output, "Could not reach"
  end

  test "off omarchy sends nothing without a terminal to ask on" do
    skip "setsid is not available" unless system("command -v setsid >/dev/null 2>&1")
    leave_omarchy

    status, output = run_collector({}, true)

    assert_equal 0, status
    assert_includes output, "Run this in a terminal"
    refute_includes output, "Could not reach"
  end

  test "off omarchy says yes only when told to, and then tries the server" do
    leave_omarchy

    status, output = run_collector("OMAHCL_SUBMIT" => "yes")

    refute_equal 0, status
    assert_includes output, "Could not reach Omarchy HCL"
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

  test "both modes explain the privacy policy and link to it before asking" do
    _status, omarchy = run_collector("OMAHCL_SUBMIT" => "no")
    leave_omarchy
    _status, candidate = run_collector("OMAHCL_SUBMIT" => "no")

    { "omarchy" => omarchy, "candidate" => candidate }.each do |mode, output|
      assert_includes output, "Privacy policy: http://example.test/privacy", mode
      assert_includes output, "plus the DMI serials when run with sudo", mode
      assert_includes output, "never sends serial numbers, MAC addresses, your hostname or username", mode
      assert_includes output, "IP address", mode
    end
    assert_includes omarchy, "The report is public."
    assert_includes candidate, "Candidate reports are never shown publicly."
  end

  test "macos is explained and never inspected" do
    status, output = run_collector("OMAHCL_KERNEL" => "Darwin", "OMAHCL_ARCH" => "arm64")

    assert_equal 0, status
    assert_includes output, "Apple silicon"
    assert_includes output, "unlikely"
    refute_includes output, "Could not reach"

    status, output = run_collector("OMAHCL_KERNEL" => "Darwin", "OMAHCL_ARCH" => "x86_64")

    assert_equal 0, status
    assert_includes output, "Intel Mac"
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
