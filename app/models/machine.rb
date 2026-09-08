class Machine < ApplicationRecord
  belongs_to :user
  belongs_to :report
  has_many :listings, dependent: :destroy

  validates :report_id, uniqueness: true

  def open_listing
    listings.find { |listing| listing.status != "closed" }
  end
end
