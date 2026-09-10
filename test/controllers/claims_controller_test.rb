require "test_helper"

class ClaimsControllerTest < ActionDispatch::IntegrationTest
  test "signed-in user can claim a report" do
    report, token = ingest_report!
    sign_in_as(users(:one))

    post claim_report_path(report.public_id), params: { token: token }

    assert_redirected_to me_reports_path
    follow_redirect!
    assert_response :success
    assert_select "div", /This machine is on your account/
    assert_select "h1", "My machines"
    assert_equal users(:one), report.reload.user
    assert report.claimed?
  end

  test "claim page talks about the machine" do
    report, token = ingest_report!
    sign_in_as(users(:one))

    get claim_report_path(report.public_id), params: { token: token }

    assert_response :success
    assert_select "h1", "Add this machine"
    assert_select "button", "Add it to my account"
  end

  test "invalid token is rejected" do
    report, _token = ingest_report!
    sign_in_as(users(:one))

    post claim_report_path(report.public_id), params: { token: "nope" }

    assert_redirected_to root_path
    assert_nil report.reload.user_id
  end
end
