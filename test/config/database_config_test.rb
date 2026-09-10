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

  test "cache queue and cable have migrations so a shared DATABASE_URL gets their tables" do
    {
      "cache" => "solid_cache_entries",
      "queue" => "solid_queue_jobs",
      "cable" => "solid_cable_messages"
    }.each do |role, table|
      files = Rails.root.join("db/#{role}_migrate").glob("*.rb")
      assert files.any?, "db/#{role}_migrate"
      assert files.any? { |file| file.read.include?(table) }, "#{role} creates #{table}"
    end
  end
end
