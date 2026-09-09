class User < ApplicationRecord
  MAX_CLAIMED_MACHINES = 5

  has_secure_password
  has_many :sessions, dependent: :destroy

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end
  has_many :reports, dependent: :nullify
  has_many :machines, dependent: :destroy
  has_many :listings, through: :machines

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
