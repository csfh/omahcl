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

  MAX_SEARCH_TERMS = 8
  # Close matches, tried only when nothing matches exactly, and only for a word of five
  # letters or more. A word with a digit is a model code, where one wrong character is
  # another machine ("x510uqs" scores 0.75 against "x510uqr"). Of the letters-only words
  # measured on real data, typos score 0.545 to 0.75 ("thnkpad", "latitdue", "framwork",
  # "vivobok") and different product words 0.5 or less ("thinkbook" and "thinkpad",
  # "ideapad" and "ideacentre"). Tests pin both sides.
  FUZZY_WORD = /\A[[:alpha:]]{5,}\z/
  FUZZY_THRESHOLD = 0.52

  # Every word must appear somewhere in the search document, in any order, so
  # "asus x510" and "carbon thinkpad" find their machines. A Mac is also found by the
  # marketing name for its identifier, read from the table now, so a row whose
  # search_document predates a change to config/mac_models.yml still matches.
  # fuzzy lets a long word be a few letters off, by trigram word similarity.
  scope :for_query, ->(query, fuzzy: false) {
    terms = query.to_s.split.first(MAX_SEARCH_TERMS)
    if terms.any?
      named = terms.inject(all) do |found, term|
        like = "%#{sanitize_sql_like(term)}%"
        if fuzzy && term.match?(FUZZY_WORD)
          found.where("search_document ILIKE :like OR word_similarity(:term, search_document) >= :threshold", like: like, term: term, threshold: FUZZY_THRESHOLD)
        else
          found.where("search_document ILIKE ?", like)
        end
      end
      fuzzy ? named : named.or(where(vendor: "Apple", product: Display.mac_identifiers_matching(terms.join(" "))))
    else
      all
    end
  }

  # A model is found when one of its machines matches, and then counts all of its
  # machines: a search for a CPU must not shrink the model's count or memory range.
  # vendor is a vendor's name as the charts spell it, whatever its case.
  def self.grouped_models(query = nil, vendor: nil, fuzzy: false)
    models = visible
    models = models.where("LOWER(vendor) = ?", vendor.to_s.downcase) if vendor.present?
    models = models.where(model_key: visible.for_query(query, fuzzy: fuzzy).select(:model_key)) if query.to_s.split.any?
    order = "COUNT(DISTINCT instance_digest) DESC, MIN(vendor) ASC, MIN(product) ASC"
    order = [ sanitize_sql_array([ "MAX(word_similarity(?, search_document)) DESC", query.to_s ]), order ].join(", ") if fuzzy && query.to_s.split.any?
    models
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
      .order(Arel.sql(order))
  end

  # The newest reports, one row per model, for the home page's "just reported" list.
  # created_at, not updated_at: a machine reporting again is not news.
  def self.recent_models(limit = 5)
    visible
      .select(:model_key, :model_slug, "MIN(vendor) AS vendor", "MIN(product) AS product", "MIN(family) AS family", "MAX(created_at) AS reported_at")
      .group(:model_key, :model_slug)
      .order(Arel.sql("MAX(created_at) DESC, MIN(vendor) ASC, MIN(product) ASC"))
      .limit(limit)
  end

  # One real card for the home page: the most-reported configuration, ties broken by
  # key so the pick does not change between visits. Returns a report that holds it.
  def self.featured_card
    key = visible.group(:card_key).order(Arel.sql("COUNT(DISTINCT instance_digest) DESC, card_key ASC")).pick(:card_key)
    visible.where(card_key: key).order(updated_at: :desc).first if key
  end

  # What a search matches: the stored names, the name pages show, and the CPU and GPU
  # names pages show, so a machine is found by "Vivobook X510" or "Ryzen" as well as by
  # what its firmware calls it. Display rules change this text, so a change to them
  # needs a migration that rebuilds it, like
  # 20261023130000_add_cpu_and_gpu_to_search_documents.rb.
  def self.search_document_for(vendor, product, family, cpu_model: nil, gpus: nil)
    stored = [ vendor, product, family ].compact.join(" ")
    shown = Display.model(vendor, product, family)
    name = stored.downcase.include?(shown.downcase) ? stored : "#{stored} #{shown}"
    # gpus is JSON a collector wrote, so anything that is not a list of objects is skipped.
    listed = gpus.is_a?(Array) ? gpus.grep(Hash) : []
    [ name, Display.cpu(cpu_model), *Display.gpus(listed) ].reject(&:blank?).join(" ")
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
      self.search_document = self.class.search_document_for(vendor, product, family, cpu_model: cpu_model, gpus: gpus)
    end
end
