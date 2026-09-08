require "test_helper"

class ClaimsControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can claim a report" do
    report, token = Report.ingest(payload, ip: "203.0.113.4")
    sign_in_as(users(:one))

    post claim_report_path(report.public_id), params: { token: token }

    assert_redirected_to me_machines_path
    follow_redirect!
    assert_response :success
    assert_equal users(:one), report.reload.user
    assert Machine.exists?(report: report, user: users(:one))
  end

  test "invalid token is rejected" do
    report, _token = Report.ingest(payload, ip: "203.0.113.4")
    sign_in_as(users(:one))

    post claim_report_path(report.public_id), params: { token: "nope" }

    assert_redirected_to root_path
    assert_nil report.reload.user_id
  end

  private
    def payload
      {
        "omarchy" => { "version" => "4.0.2", "channel" => "stable" },
        "hardware" => {
          "vendor" => "LENOVO",
          "product" => "ThinkPad X220",
          "cpu" => { "model" => "Intel Core i5-2520M", "arch" => "x86_64", "cores" => 2 },
          "memory_bytes" => 2_147_483_648,
          "gpus" => [],
          "uefi" => true
        }
      }
    end
end
