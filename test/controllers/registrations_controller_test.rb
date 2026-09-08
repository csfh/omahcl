require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
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
