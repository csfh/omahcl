ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def omarchy_payload(product: "ThinkPad X220", cpu: "Intel Core i5-2520M", instance_digest: ::Digest::SHA256.hexdigest(SecureRandom.hex(16)))
      {
        "omarchy" => { "version" => "4.0.2", "channel" => "stable" },
        "hardware" => {
          "vendor" => "LENOVO",
          "product" => product,
          "family" => product,
          "chassis" => "Notebook",
          "cpu" => { "model" => cpu, "vendor" => "Intel", "arch" => "x86_64", "cores" => 2 },
          "memory_bytes" => 2_147_483_648,
          "gpus" => [ { "vendor" => "Intel", "name" => "HD Graphics 3000" } ],
          "uefi" => true,
          "tpm" => { "present" => false },
          "secure_boot" => { "enabled" => false }
        },
        "instance_digest" => instance_digest
      }
    end

    def candidate_payload(product: "ThinkPad X220", cpu: "Intel Core i5-2520M", instance_digest: ::Digest::SHA256.hexdigest(SecureRandom.hex(16)), verdict: "likely")
      omarchy_payload(product: product, cpu: cpu, instance_digest: instance_digest)
        .except("omarchy")
        .merge("source" => "candidate", "verdict" => verdict, "host_os" => "ubuntu")
    end

    def ingest_report!(payload = omarchy_payload)
      nonce, _challenge = Challenge.issue!
      Report.ingest(payload.merge("nonce" => nonce))
    end
  end
end
