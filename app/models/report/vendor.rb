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

  def self.canonical(raw)
    text = raw.to_s.strip.gsub(/\s+/, " ")
    name = text.sub(SUFFIX, "")
    name = text if name.blank?
    BRANDS.fetch(brand_key(name)) { name }
  end

  def self.brand_key(name)
    name.downcase.gsub(/[^a-z0-9]+/, " ").strip
  end
end
