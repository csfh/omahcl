# One spelling per vendor, so "Dell Inc.", "Dell  Inc." and "DELL" are one vendor
# with one model page. The raw string stays in facts; only the stored vendor, and
# the model_key, slug and card key built from it, use this name. The client's
# instance_digest hashes the raw string and is never touched by it.
module Report::Vendor
  # Corporate forms that say nothing about the brand.
  SUFFIX = /(?:[\s,]+(?:inc|incorporated|corp|corporation|co|company|ltd|limited|llc|gmbh|ag)\b\.?)+\s*\z/i

  # Keyed by the lowercase vendor with suffixes and punctuation removed.
  BRANDS = {
    "acer" => "Acer",
    "apple" => "Apple",
    "asrock" => "ASRock",
    "asus" => "ASUS",
    "asustek computer" => "ASUS",
    "dell" => "Dell",
    "framework" => "Framework",
    "gigabyte technology" => "Gigabyte",
    "gigabyte" => "Gigabyte",
    "hewlett packard" => "HP",
    "hp" => "HP",
    "huawei" => "Huawei",
    "lenovo" => "Lenovo",
    "microsoft" => "Microsoft",
    "micro star international" => "MSI",
    "msi" => "MSI",
    "razer" => "Razer",
    "samsung electronics" => "Samsung",
    "samsung" => "Samsung",
    "system76" => "System76"
  }.freeze

  # The outline of a vendor's logo, from config/vendor_logos.yml (built by
  # script/vendor_logos.rb), by the vendor's slug. Nil for a vendor without one.
  LOGOS = YAML.load_file(Rails.root.join("config/vendor_logos.yml")).freeze

  def self.canonical(raw)
    text = raw.to_s.strip.gsub(/\s+/, " ")
    name = text.sub(SUFFIX, "")
    name = text if name.blank?
    BRANDS.fetch(brand_key(name)) { name }
  end

  # A /models address from before a vendor was renamed ("dell-inc-xps-14-da14260") as a
  # search that finds the model's current page ("Dell xps 14 da14260"). Best effort: it
  # rewrites a known vendor prefix and drops corporate suffixes after it.
  def self.query_from_slug(slug)
    words = slug.to_s.tr("-", " ").squish
    return if words.empty?

    key = BRANDS.keys.sort_by { |name| -name.size }.find { |name| words == name || words.start_with?("#{name} ") }
    return words unless key

    rest = words.delete_prefix(key).strip
    rest = rest.sub(/\A(?:(?:inc|incorporated|corp|corporation|co|company|ltd|limited|llc|gmbh|ag)\b\s*)+/i, "")
    [ BRANDS[key], rest ].reject(&:empty?).join(" ")
  end

  # A vendor's address on /vendors. The chart, the sitemap and the page itself all
  # take it from here, and it always fits the route: lowercase letters and digits
  # joined by single hyphens (parameterize keeps underscores). Blank for a name with
  # no ASCII letters or digits, which has no page.
  def self.slug(name)
    name.to_s.parameterize.tr("_", "-").squeeze("-").delete_prefix("-").delete_suffix("-")
  end

  def self.logo(name)
    LOGOS[slug(name)]
  end

  def self.brand_key(name)
    name.downcase.gsub(/[^a-z0-9]+/, " ").strip
  end
end
