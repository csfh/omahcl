require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "admin sessions keep no IP address or user agent" do
    refute_includes Session.column_names, "ip_address"
    refute_includes Session.column_names, "user_agent"
  end
end
