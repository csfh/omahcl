require "test_helper"
require "erb"
require "yaml"

class RecurringConfigTest < ActiveSupport::TestCase
  test "production deletes expired challenges on a schedule" do
    task = production_tasks.fetch("delete_expired_challenges")

    assert_equal "Challenge.expired.delete_all", task["command"]
    assert_equal "every 5 minutes", task["schedule"]
  end

  # Rate-limit keys hold client IPs. Solid Cache only evicts while writes come
  # in, so a timer makes sure they are gone soon after max_age.
  test "production deletes cache entries older than max_age on a schedule" do
    task = production_tasks.fetch("delete_old_cache_entries")

    assert_equal "SolidCache::Entry.where(created_at: ...Rails.cache.max_age.seconds.ago).delete_all", task["command"]
    assert_equal "every 5 minutes", task["schedule"]
  end

  private
    def production_tasks
      YAML.safe_load(ERB.new(Rails.root.join("config/recurring.yml").read).result).fetch("production")
    end
end
