class ReportSanitizer
  class Rejected < StandardError; end

  DENIED_KEY_FRAGMENTS = %w[
    serial
    mac
    hostname
    username
    user_name
    uuid
    ip_address
    ssh
  ].freeze

  ALLOWED_ROOT = %w[source verdict host_os omarchy hardware instance_digest].freeze
  SOURCES = %w[omarchy candidate].freeze
  VERDICTS = %w[likely unclear unlikely].freeze
  INSTANCE_DIGEST = /\A[a-f0-9]{64}\z/
  ALLOWED_OMARCHY = %w[version channel].freeze
  ALLOWED_HARDWARE = %w[
    vendor product family chassis cpu memory_bytes gpus uefi tpm secure_boot
  ].freeze
  ALLOWED_CPU = %w[model vendor arch cores].freeze
  ALLOWED_GPU = %w[vendor name].freeze
  ALLOWED_TPM = %w[present].freeze
  ALLOWED_SECURE_BOOT = %w[enabled].freeze

  def self.clean!(raw)
    new(raw).clean!
  end

  def initialize(raw)
    @raw = raw
  end

  def clean!
    raise Rejected, "payload must be an object" unless @raw.is_a?(Hash)

    reject_denied_keys!(@raw)
    assert_allowed_keys!(@raw, ALLOWED_ROOT, "payload")

    source = (@raw["source"].presence || "omarchy").to_s
    raise Rejected, "source must be one of #{SOURCES.join(', ')}" unless SOURCES.include?(source)
    candidate = source == "candidate"

    if candidate
      raise Rejected, "candidate reports must not include omarchy" if @raw.key?("omarchy")
      verdict = @raw["verdict"].to_s
      raise Rejected, "verdict must be one of #{VERDICTS.join(', ')}" unless VERDICTS.include?(verdict)
      host_os = optional_string(@raw["host_os"])&.downcase&.first(40)
      omarchy = {}
    else
      raise Rejected, "only candidate reports may include verdict or host_os" if @raw.key?("verdict") || @raw.key?("host_os")
      verdict = host_os = nil
      omarchy = require_hash(@raw["omarchy"], "omarchy")
    end

    hardware = require_hash(@raw["hardware"], "hardware")

    assert_allowed_keys!(omarchy, ALLOWED_OMARCHY, "omarchy")
    assert_allowed_keys!(hardware, ALLOWED_HARDWARE, "hardware")

    cpu = require_hash(hardware["cpu"], "cpu")
    assert_allowed_keys!(cpu, ALLOWED_CPU, "cpu")

    gpus = hardware["gpus"]
    raise Rejected, "gpus must be an array" unless gpus.is_a?(Array)
    raise Rejected, "too many GPUs" if gpus.size > 8

    gpus.each_with_index do |gpu, index|
      raise Rejected, "gpus[#{index}] must be an object" unless gpu.is_a?(Hash)
      assert_allowed_keys!(gpu, ALLOWED_GPU, "gpus[#{index}]")
    end

    tpm = hardware["tpm"]
    if tpm
      tpm = require_hash(tpm, "tpm")
      assert_allowed_keys!(tpm, ALLOWED_TPM, "tpm")
    end

    secure_boot = hardware["secure_boot"]
    if secure_boot
      secure_boot = require_hash(secure_boot, "secure_boot")
      assert_allowed_keys!(secure_boot, ALLOWED_SECURE_BOOT, "secure_boot")
    end

    instance_digest = present_string(@raw["instance_digest"], "instance_digest")
    raise Rejected, "instance_digest must be 64 hex characters" unless instance_digest.match?(INSTANCE_DIGEST)

    version = candidate ? nil : present_string(omarchy["version"], "omarchy.version")
    channel = candidate ? "stable" : present_string(omarchy["channel"].presence || "stable", "omarchy.channel")
    vendor = present_string(hardware["vendor"], "hardware.vendor")
    product = present_string(hardware["product"], "hardware.product")
    cpu_model = present_string(cpu["model"], "cpu.model")
    cpu_arch = present_string(cpu["arch"], "cpu.arch")

    {
      source: source,
      verdict: verdict,
      host_os: host_os,
      instance_digest: instance_digest,
      omarchy_version: version,
      omarchy_channel: channel,
      vendor: vendor,
      product: product,
      family: optional_string(hardware["family"]),
      chassis: optional_string(hardware["chassis"]),
      cpu_model: cpu_model,
      cpu_vendor: optional_string(cpu["vendor"]),
      cpu_arch: cpu_arch,
      cpu_cores: integer_value(cpu["cores"], "cpu.cores"),
      memory_bytes: integer_value(hardware["memory_bytes"], "hardware.memory_bytes"),
      gpus: gpus.map { |gpu| { "vendor" => optional_string(gpu["vendor"]), "name" => optional_string(gpu["name"]) }.compact_blank },
      uefi: boolean_value(hardware["uefi"]),
      tpm_present: boolean_value(tpm && tpm["present"]),
      secure_boot_enabled: boolean_value(secure_boot && secure_boot["enabled"]),
      facts: {
        "omarchy" => (candidate ? nil : { "version" => version, "channel" => channel }),
        "hardware" => {
          "vendor" => vendor,
          "product" => product,
          "family" => optional_string(hardware["family"]),
          "chassis" => optional_string(hardware["chassis"]),
          "cpu" => {
            "model" => cpu_model,
            "vendor" => optional_string(cpu["vendor"]),
            "arch" => cpu_arch,
            "cores" => integer_value(cpu["cores"], "cpu.cores")
          },
          "memory_bytes" => integer_value(hardware["memory_bytes"], "hardware.memory_bytes"),
          "gpus" => gpus.map { |gpu| { "vendor" => optional_string(gpu["vendor"]), "name" => optional_string(gpu["name"]) }.compact_blank },
          "uefi" => boolean_value(hardware["uefi"]),
          "tpm" => { "present" => boolean_value(tpm && tpm["present"]) },
          "secure_boot" => { "enabled" => boolean_value(secure_boot && secure_boot["enabled"]) }
        }
      }.compact
    }
  end

  private
    def reject_denied_keys!(value)
      case value
      when Hash
        value.each do |key, child|
          name = key.to_s.downcase
          if DENIED_KEY_FRAGMENTS.any? { |fragment| name.include?(fragment) }
            raise Rejected, "refused identifier field #{key}"
          end
          reject_denied_keys!(child)
        end
      when Array
        value.each { |child| reject_denied_keys!(child) }
      end
    end

    def assert_allowed_keys!(hash, allowed, label)
      unknown = hash.keys.map(&:to_s) - allowed
      raise Rejected, "unknown #{label} fields: #{unknown.join(', ')}" if unknown.any?
    end

    def require_hash(value, label)
      raise Rejected, "#{label} must be an object" unless value.is_a?(Hash)
      value
    end

    def present_string(value, label)
      text = optional_string(value)
      raise Rejected, "#{label} is required" if text.blank?
      text
    end

    def optional_string(value)
      return if value.nil?
      text = value.to_s.strip.gsub(/[\r\n\t]+/, " ")
      text.presence&.truncate(240)
    end

    def integer_value(value, label)
      return 0 if value.nil? || value == ""
      Integer(value)
    rescue ArgumentError, TypeError
      raise Rejected, "#{label} must be an integer"
    end

    def boolean_value(value)
      ActiveModel::Type::Boolean.new.cast(value) || false
    end
end
