require "test_helper"
require "erb"
require "yaml"

class RecurringConfigTest < ActiveSupport::TestCase
  test "production deletes expired challenges on a schedule" do
    tasks = YAML.safe_load(ERB.new(Rails.root.join("config/recurring.yml").read).result).fetch("production")
    task = tasks.fetch("delete_expired_challenges")

    assert_equal "Challenge.expired.delete_all", task["command"]
    assert_equal "every 5 minutes", task["schedule"]
  end
end
