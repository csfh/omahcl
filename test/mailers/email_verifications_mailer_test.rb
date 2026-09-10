require "test_helper"

class EmailVerificationsMailerTest < ActionMailer::TestCase
  test "verify sends a one-time confirmation link" do
    user = User.create!(email_address: "unverified@example.com", password: "password12")
    mail = EmailVerificationsMailer.verify(user)

    assert_equal [ "noreply@omarchy.csfh.dev" ], mail.from
    assert_equal [ user.email_address ], mail.to
    assert_equal "Verify your Market email", mail.subject
    assert_match %r{/email_verifications/}, mail.body.encoded
  end
end
