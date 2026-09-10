require "test_helper"

class ChallengeTest < ActiveSupport::TestCase
  test "status_label follows consume and expiry" do
    nonce, challenge = Challenge.issue!(ip: "203.0.113.10")

    assert challenge.still_open?
    assert_equal "Open", challenge.status_label

    Challenge.consume!(nonce)
    challenge.reload

    assert challenge.consumed?
    assert_equal "Consumed", challenge.status_label

    stale = Challenge.create!(
      nonce_digest: Challenge.digest_nonce("stale"),
      expires_at: 1.minute.ago
    )

    assert stale.expired?
    assert_equal "Expired", stale.status_label
  end
end
