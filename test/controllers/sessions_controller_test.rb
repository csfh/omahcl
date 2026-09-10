require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new exposes password-manager sign-in fields" do
    get new_session_path

    assert_response :success
    assert_select "form#signin[data-turbo=false]"
    assert_select "label[for=email]", text: "Email"
    assert_select "input#email[type=email][autocomplete=email][required]"
    assert_select "label[for=current-password]", text: "Password"
    assert_select "input#current-password[type=password][autocomplete=current-password][required]"
    assert_select "form#signin a", count: 0
    assert_select "nav a[href=?][data-turbo=false]", new_session_path
    assert_select "nav a[href=?][data-turbo=false]", new_registration_path
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "create with unverified email resends the link and stays signed out" do
    user = User.create!(email_address: "unverified@example.com", password: "password12")

    assert_enqueued_email_with EmailVerificationsMailer, :verify, args: [ user ] do
      post session_path, params: { email_address: user.email_address, password: "password12" }
    end

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]

    follow_redirect!
    assert_select "div", /Verify your email/
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
