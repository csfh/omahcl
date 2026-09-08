class DonationDestination < ApplicationRecord
  has_many :listings, dependent: :restrict_with_exception

  validates :name, :url, presence: true
  validates :url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  scope :active, -> { where(active: true).order(:name) }
end
