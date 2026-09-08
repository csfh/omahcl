class Report < ApplicationRecord
  CLAIM_TTL = 7.days

  belongs_to :user, optional: true
  has_one :machine, dependent: :restrict_with_exception

  before_validation :assign_public_id, on: :create
  before_validation :assign_model_identity

  validates :public_id, :omarchy_version, :vendor, :product, :cpu_model, :cpu_arch, :model_key, :model_slug, presence: true
  validates :memory_bytes, :cpu_cores, numericality: { greater_than_or_equal_to: 0 }

  scope :for_query, ->(query) {
    if query.present?
      where("search_document ILIKE ?", "%#{sanitize_sql_like(query.strip)}%")
    else
      all
    end
  }

  def self.grouped_models(query = nil)
    for_query(query)
      .select(
        :model_key, :model_slug,
        "MIN(vendor) AS vendor",
        "MIN(product) AS product",
        "COUNT(*) AS reports_count",
        "MIN(memory_bytes) AS min_memory_bytes",
        "MAX(memory_bytes) AS max_memory_bytes"
      )
      .group(:model_key, :model_slug)
      .order("reports_count DESC, vendor ASC, product ASC")
  end

  def self.ingest(raw, ip:)
    attrs = ReportSanitizer.clean!(raw)
    report = new(attrs)
    report.submitted_ip_digest = digest_ip(ip)
    token = report.rotate_claim_token
    report.save!
    [ report, token ]
  end

  def self.digest_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  def self.digest_ip(ip)
    Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{ip}")
  end

  def rotate_claim_token
    token = SecureRandom.urlsafe_base64(32)
    self.claim_token_digest = self.class.digest_token(token)
    self.claim_token_expires_at = CLAIM_TTL.from_now
    token
  end

  def claimable?(token)
    user_id.nil? &&
      claim_token_digest.present? &&
      claim_token_expires_at&.future? &&
      ActiveSupport::SecurityUtils.secure_compare(claim_token_digest, self.class.digest_token(token))
  end

  def claim!(user:, token:)
    raise ActiveRecord::RecordInvalid, self unless claimable?(token)

    transaction do
      update!(
        user: user,
        claimed_at: Time.current,
        claim_token_digest: nil,
        claim_token_expires_at: nil
      )
      Machine.create!(user: user, report: self)
    end
  end

  def claimed?
    user_id.present? && claimed_at.present?
  end

  def display_name
    [ vendor, product ].compact.join(" ")
  end

  private
    def assign_public_id
      self.public_id ||= SecureRandom.uuid
    end

    def assign_model_identity
      self.vendor = vendor.to_s.strip
      self.product = product.to_s.strip
      self.model_key = [ vendor.downcase, product.downcase ].join("|")
      self.model_slug = [ vendor, product ].join(" ").parameterize
      self.search_document = [ vendor, product, family ].compact.join(" ")
    end
end
