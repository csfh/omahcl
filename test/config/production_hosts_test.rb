require "test_helper"
require "json"
require "open3"

# config.hosts only applies in production, so this boots production in a
# subprocess and sends requests straight to the app. Only /collect and /up are
# used because they need no database.
class ProductionHostsTest < ActiveSupport::TestCase
  PROBE = <<~'RUBY'
    request = ->(path, env) { Rack::MockRequest.new(Rails.application).get(path, env) }
    results = {
      forged_host: request.("/collect", "HTTP_HOST" => "evil.example").status,
      forged_forwarded_host: request.("/collect", "HTTP_HOST" => "omahcl.com", "HTTP_X_FORWARDED_HOST" => "evil.example").status,
      health_check: request.("/up", "HTTP_HOST" => "10.0.0.5").status,
      cloud_domain: request.("/collect", "HTTP_HOST" => "omarchy-hcl-production-2mzewm.laravel.cloud").status,
      collect_url_line: request.("/collect", "HTTP_HOST" => "omahcl.com").body[/^OMAHCL_URL=.*$/]
    }
    puts "PROBE #{results.to_json}"
  RUBY

  test "production rejects forged hosts and serves the collector for its own host" do
    env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "DATABASE_URL" => "postgres://unused@127.0.0.1:1/unused" }
    output, status = Open3.capture2e(env, "bin/rails", "runner", PROBE, chdir: Rails.root.to_s)
    assert status.success?, output

    results = JSON.parse(output[/^PROBE (.*)$/, 1])

    assert_equal 403, results["forged_host"]
    assert_equal 403, results["forged_forwarded_host"]
    assert_equal 200, results["health_check"]
    assert_equal 200, results["cloud_domain"], "Laravel Cloud's docs say to allow the Cloud domain"
    assert_equal "OMAHCL_URL=${OMAHCL_URL:-https://omahcl.com}", results["collect_url_line"]
  end
end
