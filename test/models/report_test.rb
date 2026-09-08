require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "ingest stores a claimable report grouped by vendor and product" do
    report, token = Report.ingest(valid_payload, ip: "203.0.113.10")

    assert report.persisted?
    assert_equal "lenovo|thinkpad x220", report.model_key
    assert_equal "lenovo-thinkpad-x220", report.model_slug
    assert report.claimable?(token)
    refute_equal token, report.claim_token_digest
    assert_not_nil report.submitted_ip_digest
    refute_includes report.submitted_ip_digest, "203.0.113"
  end

  test "claim attaches a machine to the user" do
    report, token = Report.ingest(valid_payload, ip: "203.0.113.10")
    user = users(:one)

    machine = report.claim!(user: user, token: token)

    assert_equal user, report.reload.user
    assert_equal user, machine.user
    assert_equal report, machine.report
    refute report.claimable?(token)
  end

  test "expired or wrong tokens are not claimable" do
    report, token = Report.ingest(valid_payload, ip: "203.0.113.10")

    refute report.claimable?("nope")
    report.update!(claim_token_expires_at: 1.minute.ago)
    refute report.claimable?(token)
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
