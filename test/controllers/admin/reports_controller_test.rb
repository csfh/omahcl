require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_reports_path
    assert_redirected_to root_path
  end

  test "admin can list and open a report without seeing the ip digest" do
    report = ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    sign_in_as(users(:admin))
    get admin_reports_path

    assert_response :success
    assert_select "a", text: /ThinkPad X220/

    get admin_report_path(report.public_id)
    assert_response :success
    assert_select "h1", /ThinkPad X220/
    assert_no_match(/submitted_ip/, response.body)
    assert_no_match(report.submitted_ip_digest, response.body)
  end
end
