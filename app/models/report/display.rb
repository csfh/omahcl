# How hardware strings read on public pages. Reports keep what the machine said;
# nothing here is stored, and card_key still hashes the raw cpu_model.
module Report::Display
  GIB = 1024**3

  # Intel-era Macs report a model identifier ("MacBookPro12,1"). See the file for its source.
  MAC_MODELS = YAML.load_file(Rails.root.join("config/mac_models.yml")).freeze

  # Sizes a machine is sold with. A machine reports less than it has installed, so
  # its memory is shown as the first size that holds it.
  MEMORY_SIZES = [ 1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024 ].freeze

  # "Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz" reads "Intel Core i7-8550U".
  # short drops the maker, for the card, where the room is small.
  def self.cpu(raw, short: false)
    name = raw.to_s.strip
    return name if name.empty? || name.match?(/\AUnknown/i)

    name = name.gsub(/\((?:R|TM|C)\)/i, "")
      .sub(/\s*@\s*[\d.]+\s*[GM]Hz\b/i, "")
      .sub(/\s+(?:w\/|with)\s+Radeon.*\z/i, "")
      .sub(/\s+\d+-Core Processor\z/i, "")
      .gsub(/\s+(?:CPU|Processor)\b/i, "")
      .gsub(/\s+/, " ").strip
    name = name.sub(/\A((?:\d+(?:st|nd|rd|th) Gen )?)(?:Intel|AMD) /i, '\1') if short
    name.presence || raw.to_s.strip
  end

  # "Advanced Micro Devices, Inc. [AMD/ATI]" is AMD.
  def self.gpu_vendor(raw)
    case raw.to_s
    when /intel/i then "Intel"
    when /nvidia/i then "NVIDIA"
    when /advanced micro|\bAMD\b|\bATI\b/i then "AMD"
    else raw.to_s.sub(Report::Vendor::SUFFIX, "").strip
    end
  end

  # lspci names a card "Panther Lake [Arc B390]": the code name, then the product in
  # brackets. Show the product, with its maker unless short or already in the name.
  def self.gpu(vendor, name, short: false)
    product = name.to_s[/\[([^\]]+)\]/, 1] || name.to_s
    product = product.gsub(/\s+/, " ").strip
    maker = gpu_vendor(vendor)
    return product if short || maker.blank? || product.downcase.start_with?(maker.downcase)
    [ maker, product ].join(" ")
  end

  def self.gpus(list, short: false)
    list.map { |gpu| gpu(gpu["vendor"], gpu["name"], short: short) }.reject(&:blank?).uniq
  end

  # Lenovo's product is a machine-type code ("20XXS2XU00") and its family is the name
  # people know ("ThinkPad X1 Carbon Gen 9"). Other vendors' families are too uneven
  # to trust ("103C_5336AN HP EliteBook", "GE", "Dell Laptops").
  LENOVO_CODE = /\A[0-9][0-9A-Z]{3,9}\z/

  # "HP HP EliteBook 840 G4" is "HP EliteBook 840 G4": the product often says the vendor.
  # A Lenovo code is replaced by its family, and a Mac identifier by its marketing name.
  # A Lenovo code is kept in brackets after its family, since several machine types share
  # one; a Mac identifier is not kept (see model_code). short is for the card, which has
  # room for about 48 characters: no Lenovo code, and a Mac name without "Apple",
  # "Retina" or its ports.
  def self.model(vendor, product, family = nil, short: false, code: !short)
    vendor = vendor.to_s
    product = product.to_s
    name = lenovo_family(vendor, product, family)
    if name
      return [ vendor, name, (code ? "(#{product})" : nil) ].compact.join(" ")
    end
    mac = MAC_MODELS[product] if vendor.casecmp?("Apple")
    return mac_model(vendor, mac, short) if mac
    product = clean_product(vendor, product, family)
    return product if vendor.empty? || product.match?(/\A#{Regexp.escape(vendor)}(?:\W|\z)/i)
    [ vendor, product ].reject(&:empty?).join(" ")
  end

  # The ASUS lines whose name a bare model code ("X510UQR") takes from the family field.
  # Other families are too uneven to trust (see LENOVO_CODE).
  ASUS_LINES = { "vivobook" => "Vivobook", "zenbook" => "Zenbook", "expertbook" => "ExpertBook", "proart" => "ProArt" }.freeze

  # ASUS firmware writes "Vivobook_ASUSLaptop M3504YA_M3504YA": the model code twice and
  # the maker glued to the line.
  def self.clean_product(vendor, product, family)
    name = product.sub(/_ASUSLaptop\b/i, "").sub(/(?<!\S)(\S+)_\1\z/, '\1').gsub(/\s+/, " ").strip
    line = ASUS_LINES[family.to_s.strip.downcase] if vendor.casecmp?("ASUS")
    name = "#{line} #{name}" if line && !name.include?(" ") && name.match?(/\d/)
    name.presence || product
  end

  # The identifiers whose displayed name contains the term, ignoring case.
  def self.mac_identifiers_matching(term)
    needle = term.to_s.downcase
    MAC_MODELS.select { |_, name| "apple #{name}".downcase.include?(needle) }.keys
  end

  # A Mac's name never carries its identifier: the model page shows that on its own line.
  def self.mac_model(vendor, name, short)
    return name.sub("Retina, ", "").sub(/, (?:Two|Four) Thunderbolt 3 ports/, "") if short
    "#{vendor} #{name}"
  end

  # What a model name replaced, as [label, value], so a page can show it apart from the
  # heading: a Lenovo machine type or a Mac model identifier. Nil when nothing was replaced.
  def self.model_code(vendor, product, family = nil)
    return [ "Machine type", product.to_s ] if lenovo_family(vendor.to_s, product.to_s, family)
    [ "Model identifier", product.to_s ] if vendor.to_s.casecmp?("Apple") && MAC_MODELS.key?(product.to_s)
  end

  def self.lenovo_family(vendor, product, family)
    name = family.to_s.gsub(/\s+/, " ").strip
    return unless vendor.casecmp?("Lenovo") && product.match?(LENOVO_CODE)
    # A lone word ("IDEAPAD") says nothing more than the code does.
    name if name.include?(" ") && name.match?(/\d/) && !name.match?(LENOVO_CODE) && !name.delete(" ").casecmp?(product)
  end

  def self.memory(bytes)
    gib = bytes.to_i.to_f / GIB
    return "Unknown" unless gib.positive?

    size = MEMORY_SIZES.find { |candidate| gib <= candidate }
    size ? "#{size} GB" : "#{gib.round} GB"
  end
end
