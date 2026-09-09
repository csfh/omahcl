class Listing < ApplicationRecord
  belongs_to :report
  belongs_to :donation_destination, optional: true
  has_one :user, through: :report
  has_many_attached :photos

  CONDITIONS = %w[new used].freeze

  enum :kind, { sale: "sale", donation: "donation" }, validate: true
  enum :status, { draft: "draft", published: "published", closed: "closed" }, validate: true

  attr_writer :price_amount

  validates :title, presence: true
  validates :report_id, uniqueness: { conditions: -> { where.not(status: "closed") }, message: "already has an open listing" }
  validates :price_cents, numericality: { greater_than: 0 }, if: :sale?
  validates :currency, :city, :country_code, :condition, presence: true, if: :sale?
  validates :condition, inclusion: { in: CONDITIONS }, allow_blank: true
  validates :country_code, length: { is: 2 }, allow_blank: true
  validates :donation_destination, presence: true, if: :donation?
  validate :destination_must_be_active, if: :donation?
  validate :photos_are_images
  validate :photos_count_within_limit

  scope :visible, -> { published.includes(:report, :donation_destination, photos_attachments: :blob) }
  scope :for_model, ->(slug) { joins(:report).where(reports: { model_slug: slug }) }

  before_validation :assign_price_cents_from_amount

  def close!
    update!(status: :closed)
  end

  def price
    return unless price_cents
    MoneyDisplay.new(price_cents, currency)
  end

  def price_amount
    @price_amount || (price_cents && format("%.2f", price_cents / 100.0))
  end

  private
    def assign_price_cents_from_amount
      return if @price_amount.nil?
      return if @price_amount.blank?
      self.price_cents = (@price_amount.to_d * 100).round
    end

    def destination_must_be_active
      return if donation_destination.blank? || donation_destination.active?
      errors.add(:donation_destination, "is not accepting machines")
    end

    def photos_are_images
      photos.each do |photo|
        unless photo.content_type&.start_with?("image/")
          errors.add(:photos, "must be images")
          break
        end
      end
    end

    def photos_count_within_limit
      errors.add(:photos, "are limited to 8") if photos.size > 8
    end
end
