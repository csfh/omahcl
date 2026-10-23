# How hardware strings read on public pages. Reports keep what the machine said;
# nothing here is stored, and card_key still hashes the raw cpu_model.
module Report::Display
  GIB = 1024**3

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

  # "HP HP EliteBook 840 G4" is "HP EliteBook 840 G4": the product often says the vendor.
  def self.model(vendor, product)
    vendor = vendor.to_s
    product = product.to_s
    return product if vendor.empty? || product.match?(/\A#{Regexp.escape(vendor)}(?:\W|\z)/i)
    [ vendor, product ].reject(&:empty?).join(" ")
  end

  def self.memory(bytes)
    gib = bytes.to_i.to_f / GIB
    return "Unknown" unless gib.positive?

    size = MEMORY_SIZES.find { |candidate| gib <= candidate }
    size ? "#{size} GB" : "#{gib.round} GB"
  end
end
