require "test_helper"

# The test environment turns CSRF protection off, which hides the session write
# that a CSRF token causes. Production has it on, so these tests do too.
class SessionCookieTest < ActionDispatch::IntegrationTest
  setup do
    @forgery_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection
  end

  test "public pages set no cookies" do
    ingest_report!

    [
      root_path,
      hardware_models_path(q: "x220"),
      suggestions_hardware_models_path(q: "x220"),
      hardware_model_path("lenovo-thinkpad-x220"),
      privacy_path,
      collect_path,
      challenges_path
    ].each do |path|
      get path

      assert_response :success, path
      assert_nil response.headers["Set-Cookie"], path
    end
  end

  test "the sign-in page keeps its session under a neutral cookie name" do
    get new_session_path

    set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    assert_match(/^_session=/, set_cookie)
    assert_no_match(/omarify/i, set_cookie)
  end

  test "admins sign in and get a CSRF token on admin pages" do
    get new_session_path
    token = css_select("form#signin input[name=authenticity_token]").first["value"]

    post session_path, params: { authenticity_token: token, email_address: users(:admin).email_address, password: "password" }
    assert_redirected_to root_path

    get admin_root_path
    assert_response :success
    assert_select "meta[name=csrf-token]"
  end
end
