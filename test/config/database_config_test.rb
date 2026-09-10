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

  test "queue migrations create recurring_tasks even when jobs already exists" do
    files = Rails.root.join("db/queue_migrate").glob("*.rb")
    completing = files.reject { |file| file.read.include?("return if table_exists?(:solid_queue_jobs)") }

    assert completing.any? { |file| file.read.include?("solid_queue_recurring_tasks") }

    taken = %w[migrate cache_migrate cable_migrate].flat_map { |dir|
      Rails.root.join("db/#{dir}").glob("*.rb").map { |file| file.basename.to_s.split("_").first }
    }
    completing.each do |file|
      version = file.basename.to_s.split("_").first
      refute_includes taken, version, file.basename.to_s
    end
  end

  test "production image runs Solid Queue inside Puma" do
    assert_includes Rails.root.join("Dockerfile").read, 'SOLID_QUEUE_IN_PUMA="true"'
  end

  test "Puma runs Solid Queue without forking so a 512MB app can boot" do
    source = Rails.root.join("config/puma.rb").read

    assert_includes source, "plugin :solid_queue"
    assert_includes source, "solid_queue_mode :async"
  end
end
