require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "new accounts start unverified" do
    user = User.create!(email_address: "fresh@example.com", password: "password12")

    assert_not user.email_verified?
  end

  test "verify_email! stamps email_verified_at once" do
    user = User.create!(email_address: "fresh@example.com", password: "password12")

    user.verify_email!
    verified_at = user.email_verified_at

    assert user.email_verified?
    user.verify_email!
    assert_equal verified_at, user.reload.email_verified_at
  end

  test "email verification token stops working after verify" do
    user = User.create!(email_address: "fresh@example.com", password: "password12")
    token = user.email_verification_token

    assert_equal user, User.find_by_email_verification_token!(token)
    user.verify_email!
    assert_raises(ActiveSupport::MessageVerifier::InvalidSignature) do
      User.find_by_email_verification_token!(token)
    end
  end
end
