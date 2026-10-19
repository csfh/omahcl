class Report < ApplicationRecord
  ESTABLISHED_MACHINES = 3

  enum :source, { omarchy: "omarchy", candidate: "candidate" }, prefix: true

  before_validation :assign_public_id, on: :create
  before_validation :assign_model_identity

  validates :omarchy_version, presence: true, if: :source_omarchy?
  validates :verdict, inclusion: { in: ReportSanitizer::VERDICTS }, if: :source_candidate?
  validates :public_id, :vendor, :product, :cpu_model, :cpu_arch, :model_key, :model_slug, :instance_digest, presence: true
  validates :instance_digest, uniqueness: true
  validates :memory_bytes, :cpu_cores, numericality: { greater_than_or_equal_to: 0 }

  # What public pages count: reports from machines running Omarchy that no admin hid.
  scope :visible, -> { source_omarchy.where(hidden_at: nil) }
  scope :unhidden, -> { where(hidden_at: nil) }
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
        "MIN(memory_bytes) AS min_memory_bytes",
        "MAX(memory_bytes) AS max_memory_bytes"
      )
      .group(:model_key, :model_slug)
      .order(Arel.sql("COUNT(DISTINCT instance_digest) DESC, MIN(vendor) ASC, MIN(product) ASC"))
  end

  # The client computes instance_digest, so one person can mint several. Three is
  # a sanity bar, not proof; reports store nothing from the network to check more.
  def self.established?(machines)
    machines.to_i >= ESTABLISHED_MACHINES
  end

  def self.ingest(raw)
    payload = raw.deep_stringify_keys
    nonce = payload["nonce"]
    raise ReportSanitizer::Rejected, "nonce is required" if nonce.blank?

    attrs = ReportSanitizer.clean!(payload.except("nonce"))
    attrs = attrs.merge(instance_digest: digest_instance(attrs[:instance_digest]))
    Challenge.consume!(nonce)

    report = find_or_initialize_by(instance_digest: attrs[:instance_digest])
    # A candidate post must never replace what a running Omarchy machine reported.
    return report if report.persisted? && report.source_omarchy? && attrs[:source] == "candidate"

    report.assign_attributes(attrs)
    report.save!
    report
  end

  # Deletes every report whose client digest is listed, hidden ones included, so
  # asking to be erased always works. The client holds both digests (omarchy and
  # candidate); knowing one is the proof that the machine is theirs. Returns the
  # number of reports deleted.
  def self.erase(raw)
    payload = raw.is_a?(Hash) ? raw.deep_stringify_keys : {}
    unless payload.keys.sort == %w[instance_digests nonce]
      raise ReportSanitizer::Rejected, "expected instance_digests and nonce"
    end

    digests = payload["instance_digests"]
    valid = digests.is_a?(Array) && digests.size.between?(1, 2) &&
      digests.all? { |digest| digest.is_a?(String) && digest.match?(ReportSanitizer::INSTANCE_DIGEST) }
    raise ReportSanitizer::Rejected, "instance_digests must hold 1 or 2 64-character hex digests" unless valid
    raise ReportSanitizer::Rejected, "nonce is required" if payload["nonce"].blank?

    Challenge.consume!(payload["nonce"])
    where(instance_digest: digests.map { |digest| digest_instance(digest) }).delete_all
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
      self.card_key = self.class.card_key_for(model_key, cpu_model)
      self.search_document = [ vendor, product, family ].compact.join(" ")
    end
end
