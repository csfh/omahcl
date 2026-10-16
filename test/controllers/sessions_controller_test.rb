require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:admin) }

  test "new exposes password-manager sign-in fields" do
    get new_session_path

    assert_response :success
    assert_select "form#signin[data-turbo=false]"
    assert_select "label[for=email]", text: "Email"
    assert_select "input#email[type=email][autocomplete=email][required]"
    assert_select "label[for=current-password]", text: "Password"
    assert_select "input#current-password[type=password][autocomplete=current-password][required]"
    assert_select "form#signin a", count: 0
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

  test "create refuses a valid password for an account that is not an admin" do
    post session_path, params: { email_address: users(:one).email_address, password: "password" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end

  test "a signed-in non-admin sees no admin link" do
    sign_in_as(users(:one))

    get root_path

    assert_response :success
    assert_select "nav a", text: "Admin", count: 0
    assert_select "nav button", text: "Sign out"
  end
end
