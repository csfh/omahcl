require "test_helper"
require "tmpdir"
require "fileutils"
require "json"

class CollectorTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir("market-sys")
    write("etc/os-release", <<~OS)
      NAME="Omarchy"
      ID=omarchy
      VERSION_ID="4.0.2"
    OS
    write("sys/class/dmi/id/sys_vendor", "LENOVO")
    write("sys/class/dmi/id/product_name", "ThinkPad X220")
    write("sys/class/dmi/id/product_family", "ThinkPad X220")
    write("sys/class/dmi/id/chassis_type", "10")
    write("sys/class/dmi/id/product_serial", "SHOULD-NOT-BE-READ")
    write("proc/cpuinfo", "processor\t: 0\nvendor_id\t: GenuineIntel\nmodel name\t: Intel Core i5-2520M\n")
    write("proc/meminfo", "MemTotal:        2048000 kB\n")
    FileUtils.mkdir_p(File.join(@root, "sys/firmware/efi"))
  end

  teardown do
    FileUtils.remove_entry(@root)
  end

  test "refuses to run without omarchy" do
    write("etc/os-release", "ID=arch\n")
    status, output = run_collector

    refute_equal 0, status
    assert_match(/only runs on Omarchy/, output)
  end

  test "dry run emits allowlisted json without serials" do
    status, output = run_collector("MARKET_DRY_RUN" => "1")
    payload = JSON.parse(output)

    assert_equal 0, status
    assert_equal "4.0.2", payload.dig("omarchy", "version")
    assert_equal "LENOVO", payload.dig("hardware", "vendor")
    assert_equal "ThinkPad X220", payload.dig("hardware", "product")
    dumped = JSON.generate(payload)
    refute_includes dumped, "SHOULD-NOT-BE-READ"
    refute_includes dumped.downcase, "serial"
  end

  private
    def write(relative, content)
      path = File.join(@root, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    def run_collector(extra = {})
      env = {
        "MARKET_SYS_ROOT" => @root,
        "MARKET_URL" => "http://example.test",
        "MARKET_SKIP_CMDS" => "1",
        "MARKET_ARCH" => "x86_64"
      }.merge(extra)
      script = Rails.root.join("lib/collectors/omarchy.py")
      output = IO.popen(env, [ "python3", script.to_s ], err: [ :child, :out ], &:read)
      [ $?.exitstatus, output ]
    end
end
