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

  test "an omarchy payload defaults to the omarchy source" do
    assert_equal "omarchy", ReportSanitizer.clean!(valid_payload)[:source]
  end

  test "accepts a candidate payload without omarchy details" do
    result = ReportSanitizer.clean!(candidate_payload)

    assert_equal "candidate", result[:source]
    assert_equal "unclear", result[:verdict]
    assert_equal "ubuntu", result[:host_os]
    assert_nil result[:omarchy_version]
    assert_nil result[:facts]["omarchy"]
  end

  test "rejects a candidate that claims to run omarchy" do
    payload = candidate_payload.merge("omarchy" => { "version" => "4.0.2" })

    error = assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(payload) }
    assert_match(/must not include omarchy/, error.message)
  end

  test "rejects a candidate with an unknown verdict" do
    error = assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(candidate_payload.merge("verdict" => "great")) }
    assert_match(/verdict/, error.message)
  end

  test "rejects a verdict on an omarchy payload" do
    error = assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(valid_payload.merge("verdict" => "likely")) }
    assert_match(/only candidate/, error.message)
  end

  test "rejects an unknown source" do
    assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(valid_payload.merge("source" => "admin")) }
  end

  test "candidate host_os cannot carry identifiers" do
    assert_raises(ReportSanitizer::Rejected) { ReportSanitizer.clean!(candidate_payload.merge("hostname" => "devbox")) }
  end

  private
    def candidate_payload
      valid_payload.except("omarchy").merge("source" => "candidate", "verdict" => "unclear", "host_os" => "Ubuntu")
    end

    def valid_payload
      {
        "omarchy" => { "version" => "4.0.2", "channel" => "stable" },
        "instance_digest" => "a" * 64,
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
