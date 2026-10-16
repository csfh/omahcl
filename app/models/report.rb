class Report < ApplicationRecord
  ESTABLISHED_MACHINES = 3
  ESTABLISHED_NETWORKS = 2

  before_validation :assign_public_id, on: :create
  before_validation :assign_model_identity

  validates :public_id, :omarchy_version, :vendor, :product, :cpu_model, :cpu_arch, :model_key, :model_slug, :instance_digest, presence: true
  validates :instance_digest, uniqueness: true
  validates :memory_bytes, :cpu_cores, numericality: { greater_than_or_equal_to: 0 }

  scope :visible, -> { where(hidden_at: nil) }
  scope :hidden, -> { where.not(hidden_at: nil) }
  scope :created_since, ->(time) { where(created_at: time..) }
  scope :updated_since, ->(time) { where(updated_at: time..) }
  scope :for_query, ->(query) {
    if query.present?
      where("search_document ILIKE ?", "%#{sanitize_sql_like(query.strip)}%")
    else
      all
    end
  }

  def self.grouped_models(query = nil)
    visible.for_query(query)
      .select(
        :model_key, :model_slug,
        "MIN(vendor) AS vendor",
        "MIN(product) AS product",
        "COUNT(DISTINCT instance_digest) AS machines_count",
        "COUNT(DISTINCT submitted_ip_digest) AS networks_count",
        "MIN(memory_bytes) AS min_memory_bytes",
        "MAX(memory_bytes) AS max_memory_bytes"
      )
      .group(:model_key, :model_slug)
      .order(Arel.sql("COUNT(DISTINCT instance_digest) DESC, MIN(vendor) ASC, MIN(product) ASC"))
  end

  # Machine ids come from the client, so one person can mint many. Requiring
  # reports from more than one network keeps a single source from vouching alone.
  def self.established?(machines, networks)
    machines.to_i >= ESTABLISHED_MACHINES && networks.to_i >= ESTABLISHED_NETWORKS
  end

  def self.ingest(raw, ip:)
    payload = raw.deep_stringify_keys
    nonce = payload["nonce"]
    raise ReportSanitizer::Rejected, "nonce is required" if nonce.blank?

    attrs = ReportSanitizer.clean!(payload.except("nonce"))
    Challenge.consume!(nonce)

    report = find_or_initialize_by(instance_digest: attrs[:instance_digest])
    report.assign_attributes(attrs)
    report.submitted_ip_digest = digest_ip(ip)
    report.save!
    report
  end

  def self.digest_ip(ip)
    ::Digest::SHA256.hexdigest("#{Rails.application.secret_key_base}:#{ip}")
  end

  def hidden?
    hidden_at.present?
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
