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

  test "sign up creates a session" do
    assert_difference -> { User.count }, 1 do
      post registration_path, params: {
        user: {
          email_address: "new@example.com",
          password: "password12",
          password_confirmation: "password12"
        }
      }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
  end
end
