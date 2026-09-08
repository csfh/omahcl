require "test_helper"

class ReportSanitizerTest < ActiveSupport::TestCase
  test "accepts an allowlisted payload" do
    result = ReportSanitizer.clean!(valid_payload)

    assert_equal "4.0.2", result[:omarchy_version]
    assert_equal "LENOVO", result[:vendor]
    assert_equal "ThinkPad X220", result[:product]
    assert_equal 2147483648, result[:memory_bytes]
    refute result[:facts].to_s.downcase.include?("serial")
  end

  test "rejects serial fields" do
    payload = valid_payload
    payload["hardware"]["serial"] = "PF123"

    error = assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(payload) }
    assert_match(/serial/, error.message)
  end

  test "rejects unknown hardware fields" do
    payload = valid_payload
    payload["hardware"]["hostname"] = "devbox"

    error = assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(payload) }
    assert_match(/hostname|identifier/, error.message)
  end

  test "rejects extra root keys" do
    payload = valid_payload.merge("ssh_keys" => [ "x" ])

    assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(payload) }
  end

  private
    def valid_payload
      {
        "omarchy" => { "version" => "4.0.2", "channel" => "stable" },
        "hardware" => {
          "vendor" => "LENOVO",
          "product" => "ThinkPad X220",
          "family" => "ThinkPad X220",
          "chassis" => "Notebook",
          "cpu" => { "model" => "Intel Core i5-2520M", "vendor" => "Intel", "arch" => "x86_64", "cores" => 2 },
          "memory_bytes" => 2_147_483_648,
          "gpus" => [ { "vendor" => "Intel", "name" => "HD Graphics 3000" } ],
          "uefi" => true,
          "tpm" => { "present" => false },
          "secure_boot" => { "enabled" => false }
        }
      }
    end
end
