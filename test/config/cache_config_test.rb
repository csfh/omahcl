require "test_helper"
require "erb"
require "yaml"

class CacheConfigTest < ActiveSupport::TestCase
  # Rate-limit counters are keyed by client IP. Keeping them is fine for access
  # control only while they expire.
  test "production cache entries expire within an hour but outlive every rate-limit window" do
    config = YAML.safe_load(ERB.new(Rails.root.join("config/cache.yml").read).result, aliases: true)
    max_age = config.fetch("production").dig("store_options", "max_age")

    assert max_age, "without max_age Solid Cache keeps entries for two weeks"
    assert_operator max_age, :<=, 1.hour.to_i
    assert_operator max_age, :>=, 3.minutes.to_i, "the sign-in limit counts over 3 minutes"
  end
end
