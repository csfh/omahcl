require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "new exposes password-manager signup fields" do
    get new_registration_path

    assert_response :success
    assert_select "form#signup[data-turbo=false]"
    assert_select "label[for=email]", text: "Email"
    assert_select "input#email[type=email][autocomplete=email][required]"
    assert_select "label[for=new-password]", text: "Password"
    assert_select "input#new-password[type=password][autocomplete=new-password][required]"
    assert_select "label[for=confirm-password]", text: "Confirm password"
    assert_select "input#confirm-password[type=password][autocomplete=new-password][required]"
  end

  test "sign up emails a verification link and stays signed out" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: {
        user: {
          email_address: "new@example.com",
          password: "password12",
          password_confirmation: "password12"
        }
      }
    end

    user = User.find_by!(email_address: "new@example.com")
    assert_not user.email_verified?
    assert_enqueued_email_with EmailVerificationsMailer, :verify, args: [ user ]
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]

    follow_redirect!
    assert_select "div", /Check your email/
  end
end
