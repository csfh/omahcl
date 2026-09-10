require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_email_verification_path

    assert_response :success
    assert_select "form#resend-verification[data-turbo=false]"
    assert_select "input#email[type=email][autocomplete=username][required]"
  end

  test "show verifies the account and starts a session" do
    user = User.create!(email_address: "unverified@example.com", password: "password12")

    get email_verification_path(user.email_verification_token)

    assert user.reload.email_verified?
    assert cookies[:session_id]
    assert_redirected_to root_path

    follow_redirect!
    assert_select "div", /Welcome to Market/
  end

  test "show with an invalid token stays signed out" do
    get email_verification_path("invalid token")

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]

    follow_redirect!
    assert_select "div", /invalid or has expired/
  end

  test "create resends for an unverified address without saying whether it exists" do
    user = User.create!(email_address: "unverified@example.com", password: "password12")

    assert_enqueued_email_with EmailVerificationsMailer, :verify, args: [ user ] do
      post email_verifications_path, params: { email_address: user.email_address }
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "div", /If that account needs verification/
  end

  test "create for a verified or unknown address sends no mail" do
    assert_enqueued_emails 0 do
      post email_verifications_path, params: { email_address: users(:one).email_address }
      post email_verifications_path, params: { email_address: "missing@example.com" }
    end

    assert_redirected_to new_session_path
  end
end
