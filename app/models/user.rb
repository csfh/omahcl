class User < ApplicationRecord
  MAX_CLAIMED_REPORTS = 5

  has_secure_password
  has_many :sessions, dependent: :destroy

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end
  EMAIL_VERIFICATION_EXPIRES_IN = 24.hours

  generates_token_for :email_verification, expires_in: EMAIL_VERIFICATION_EXPIRES_IN do
    [ email_address, email_verified_at ]
  end
  has_many :reports, dependent: :nullify
  has_many :listings, through: :reports

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current) unless email_verified?
  end

  def email_verification_token
    generate_token_for(:email_verification)
  end

  def email_verification_token_expires_in
    EMAIL_VERIFICATION_EXPIRES_IN
  end

  def self.find_by_email_verification_token!(token)
    find_by_token_for!(:email_verification, token)
  end
end
