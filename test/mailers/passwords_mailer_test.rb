require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset sends from Market on omarchy.csfh.dev" do
    user = users(:one)
    mail = PasswordsMailer.reset(user)

    assert_equal [ "noreply@omarchy.csfh.dev" ], mail.from
    assert_equal [ user.email_address ], mail.to
    assert_equal "Reset your password", mail.subject
    assert_match "Market", mail[:from].to_s
  end
end
