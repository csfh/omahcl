require "test_helper"

class ChallengeTest < ActiveSupport::TestCase
  test "expired covers every challenge past its expiry, consumed or not" do
    nonce, open_challenge = Challenge.issue!
    Challenge.consume!(nonce)
    _nonce, unused = Challenge.issue!
    consumed_and_expired = Challenge.create!(nonce_digest: Challenge.digest_nonce("a"), expires_at: 1.minute.ago, consumed_at: 2.minutes.ago)
    expired = Challenge.create!(nonce_digest: Challenge.digest_nonce("b"), expires_at: 1.minute.ago)

    assert_equal [ consumed_and_expired, expired ].sort_by(&:id), Challenge.expired.order(:id).to_a
    assert_includes Challenge.still_open, unused
    refute_includes Challenge.still_open, open_challenge.reload
  end

  test "challenges keep no IP data" do
    refute_includes Challenge.column_names, "issued_ip_digest"
  end
end
