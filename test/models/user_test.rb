require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "last_admin? is true only when this account is the only admin" do
    assert users(:admin).last_admin?

    User.create!(email_address: "ops@example.com", password: "password12", admin: true)
    assert_not users(:admin).reload.last_admin?
    assert_not users(:one).last_admin?
  end
end
