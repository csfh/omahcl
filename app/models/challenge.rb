class Challenge < ApplicationRecord
  TTL = 5.minutes

  def self.issue!(ip:)
    nonce = SecureRandom.urlsafe_base64(32)
    challenge = create!(
      nonce_digest: digest_nonce(nonce),
      expires_at: TTL.from_now,
      issued_ip_digest: Report.digest_ip(ip)
    )
    [ nonce, challenge ]
  end

  def self.consume!(nonce)
    digest = digest_nonce(nonce.to_s)
    updated = where(nonce_digest: digest, consumed_at: nil)
      .where("expires_at > ?", Time.current)
      .update_all(consumed_at: Time.current)
    raise ReportSanitizer::Rejected, "challenge is invalid or expired" unless updated == 1
  end

  def self.digest_nonce(nonce)
    ::Digest::SHA256.hexdigest(nonce.to_s)
  end
end
