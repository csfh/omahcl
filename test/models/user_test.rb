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

  test "last_admin? is true only when this account is the only admin" do
    assert users(:admin).last_admin?

    User.create!(email_address: "ops@example.com", password: "password12", admin: true)
    assert_not users(:admin).reload.last_admin?
    assert_not users(:one).last_admin?
  end

  test "close_open_listings! closes draft and published listings" do
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

    users(:one).close_open_listings!

    assert listing.reload.closed?
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
