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
  end

  test "admin can hide and unhide a report" do
    report = ingest_report!(omarchy_payload(product: "ThinkPad X220"))
    sign_in_as(users(:admin))

    post hide_admin_report_path(report.public_id)
    assert_redirected_to admin_report_path(report.public_id)
    assert report.reload.hidden?

    get admin_reports_path, params: { hidden: "yes" }
    assert_select "a", text: /ThinkPad X220/
    get admin_reports_path, params: { hidden: "no" }
    assert_select "a", text: /ThinkPad X220/, count: 0

    post unhide_admin_report_path(report.public_id)
    assert_not report.reload.hidden?
  end

  test "non-admin cannot hide a report" do
    report = ingest_report!
    sign_in_as(users(:one))

    post hide_admin_report_path(report.public_id)

    assert_redirected_to root_path
    assert_not report.reload.hidden?
  end
end
