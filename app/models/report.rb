class Report < ApplicationRecord
  before_validation :assign_public_id, on: :create
  before_validation :assign_model_identity

  validates :public_id, :omarchy_version, :vendor, :product, :cpu_model, :cpu_arch, :model_key, :model_slug, :instance_digest, presence: true
  validates :instance_digest, uniqueness: true
  validates :memory_bytes, :cpu_cores, numericality: { greater_than_or_equal_to: 0 }

  # What public pages count: reports that no admin hid.
  scope :visible, -> { where(hidden_at: nil) }
  scope :hidden, -> { where.not(hidden_at: nil) }
  scope :created_since, ->(time) { where(created_at: time..) }
  scope :updated_since, ->(time) { where(updated_at: time..) }
  # Also finds a Mac by the marketing name pages show for its identifier, which
  # search_document does not hold.
  scope :for_query, ->(query) {
    if query.present?
      term = query.strip
      macs = Display.mac_identifiers_matching(term)
      where("search_document ILIKE :like OR (vendor = 'Apple' AND product IN (:macs))", like: "%#{sanitize_sql_like(term)}%", macs: macs.presence || [ "" ])
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
        "MIN(family) AS family",
        "COUNT(DISTINCT instance_digest) AS machines_count",
        "MIN(memory_bytes) AS min_memory_bytes",
        "MAX(memory_bytes) AS max_memory_bytes"
      )
      .group(:model_key, :model_slug)
      .order(Arel.sql("COUNT(DISTINCT instance_digest) DESC, MIN(vendor) ASC, MIN(product) ASC"))
  end

  def self.ingest(raw)
    payload = raw.deep_stringify_keys
    nonce = payload["nonce"]
    raise ReportSanitizer::Rejected, "nonce is required" if nonce.blank?

    attrs = ReportSanitizer.clean!(payload.except("nonce"))
    attrs = attrs.merge(instance_digest: digest_instance(attrs[:instance_digest]))
    Challenge.consume!(nonce)

    report = find_or_initialize_by(instance_digest: attrs[:instance_digest])
    report.assign_attributes(attrs)
    report.save!
    report
  end

  # Deletes the report whose client digest is given, hidden or not, so asking to be
  # erased always works. Knowing the digest is the proof that the machine is theirs.
  # Returns the number of reports deleted.
  def self.erase(raw)
    payload = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
    unless payload.keys.sort == %w[instance_digest nonce]
      raise ReportSanitizer::Rejected, "expected instance_digest and nonce"
    end

    digest = payload["instance_digest"]
    unless digest.is_a?(String) && digest.match?(ReportSanitizer::INSTANCE_DIGEST)
      raise ReportSanitizer::Rejected, "instance_digest must be 64 hex characters"
    end
    raise ReportSanitizer::Rejected, "nonce is required" if payload["nonce"].blank?

    Challenge.consume!(payload["nonce"])
    where(instance_digest: digest_instance(digest)).delete_all
  end

  # One key per model and CPU, so a Framework Laptop 13 with another CPU has its own
  # card. Plain SHA-256, not keyed with secret_key_base: shared links and cached
  # previews must survive a key rotation. The version prefix lets the formula change.
  def self.card_key_for(model_key, cpu_model)
    cpu = cpu_model.to_s.strip.gsub(/\s+/, " ").downcase
    ::Digest::SHA256.hexdigest("omahcl-card-v1|#{model_key}|#{cpu}")[0, 16]
  end

  # Anyone who can read a machine's /etc/machine-id can recompute the digest the
  # collector sends, so the server stores it keyed. HashInstanceDigests converted
  # the rows stored before this and must use the same key.
  def self.digest_instance(client_digest)
    key = Rails.application.key_generator.generate_key("report instance digest")
    OpenSSL::HMAC.hexdigest("SHA256", key, client_digest)
  end

  def hidden?
    hidden_at.present?
  end

  # short is for titles and cards; code: false leaves a Lenovo type or Mac identifier out.
  def display_name(**options)
    Display.model(vendor, product, family, **options)
  end

  def model_code
    Display.model_code(vendor, product, family)
  end

  private
    def assign_public_id
      self.public_id ||= SecureRandom.uuid
    end

    def assign_model_identity
      self.vendor = Vendor.canonical(vendor)
      self.product = product.to_s.strip.gsub(/\s+/, " ")
      self.model_key = [ vendor.downcase, product.downcase ].join("|")
      self.model_slug = [ vendor, product ].join(" ").parameterize
      self.card_key = self.class.card_key_for(model_key, cpu_model)
      self.search_document = [ vendor, product, family ].compact.join(" ")
    end
end
