require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_reports_path
    assert_redirected_to root_path
  end

  test "admin can see an unclaimed report that stays off public lookup" do
    report, _token = ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    sign_in_as(users(:admin))
    get admin_reports_path

    assert_response :success
    assert_select "a", text: /ThinkPad X220/
    assert_select "p", /Unclaimed/

    get admin_report_path(report.public_id)
    assert_response :success
    assert_select "h1", /ThinkPad X220/
    assert_no_match(/claim_token/, response.body)
    assert_no_match(/submitted_ip/, response.body)

    get hardware_model_path(report.model_slug)
    assert_response :not_found
  end
end
