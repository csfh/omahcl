require "test_helper"
require "erb"
require "yaml"

class DatabaseConfigTest < ActiveSupport::TestCase
  test "production named connections use DATABASE_URL" do
    original = ENV["DATABASE_URL"]
    ENV["DATABASE_URL"] = "postgres://user:pass@db.example:25060/defaultdb?sslmode=require"

    config = YAML.safe_load(
      ERB.new(Rails.root.join("config/database.yml").read).result,
      aliases: true
    )
    production = config.fetch("production")

    %w[primary cache queue cable].each do |role|
      assert_equal ENV["DATABASE_URL"], production.dig(role, "url"), role
    end
  ensure
    ENV["DATABASE_URL"] = original
  end
end
