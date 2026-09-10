require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_users_path
    assert_redirected_to root_path
  end

  test "admin can search by email" do
    sign_in_as(users(:admin))
    get admin_users_path, params: { q: "one@" }

    assert_response :success
    assert_select "a", text: "one@example.com"
    assert_select "a", text: "two@example.com", count: 0
  end

  test "admin can mark email verified" do
    user = User.create!(email_address: "fresh@example.com", password: "password12")
    sign_in_as(users(:admin))

    post verify_email_admin_user_path(user)

    assert user.reload.email_verified?
    assert_redirected_to admin_user_path(user)
  end

  test "admin can grant and revoke admin" do
    sign_in_as(users(:admin))

    post grant_admin_admin_user_path(users(:one))
    assert users(:one).reload.admin?

    post revoke_admin_admin_user_path(users(:one))
    assert_not users(:one).reload.admin?
  end

  test "last admin cannot be revoked" do
    sign_in_as(users(:admin))

    post revoke_admin_admin_user_path(users(:admin))

    assert users(:admin).reload.admin?
    assert_redirected_to admin_user_path(users(:admin))
    assert_equal "The last admin cannot be removed.", flash[:alert]
  end

  test "admin can queue a password reset" do
    sign_in_as(users(:admin))

    assert_enqueued_email_with PasswordsMailer, :reset, args: [ users(:one) ] do
      post password_reset_admin_user_path(users(:one))
    end

    assert_redirected_to admin_user_path(users(:one))
  end

  test "admin cannot delete their own account" do
    sign_in_as(users(:admin))

    assert_no_difference -> { User.count } do
      delete admin_user_path(users(:admin))
    end

    assert_redirected_to admin_user_path(users(:admin))
    assert_equal "You cannot delete your own account.", flash[:alert]
  end

  test "admin delete closes listings and unclaims reports" do
    report, token = ingest_report!
    report.claim!(user: users(:one), token: token)
    listing = Listing.create!(
      report: report,
      kind: "sale",
      title: "Used X220",
      condition: "used",
      price_amount: "150",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "published"
    )
    sign_in_as(users(:admin))

    assert_difference -> { User.count }, -1 do
      delete admin_user_path(users(:one))
    end

    assert listing.reload.closed?
    assert_nil report.reload.user_id
    assert_redirected_to admin_users_path
  end
end
