require "test_helper"

class CloudflareEmailSmtpTest < ActiveSupport::TestCase
  setup { @original_token = ENV["CLOUDFLARE_EMAIL_API_TOKEN"] }
  teardown { ENV["CLOUDFLARE_EMAIL_API_TOKEN"] = @original_token }

  test "settings submit over implicit TLS with the api_token username" do
    ENV["CLOUDFLARE_EMAIL_API_TOKEN"] = "cfut_test_token"

    settings = CloudflareEmailSmtp.settings

    assert_equal "smtp.mx.cloudflare.net", settings[:address]
    assert_equal 465, settings[:port]
    assert_equal "api_token", settings[:user_name]
    assert_equal "cfut_test_token", settings[:password]
    assert_equal :plain, settings[:authentication]
    assert_equal true, settings[:tls]
    assert_equal false, settings[:enable_starttls]
    assert_equal false, settings[:enable_starttls_auto]
  end

  test "settings require CLOUDFLARE_EMAIL_API_TOKEN" do
    ENV.delete("CLOUDFLARE_EMAIL_API_TOKEN")

    error = assert_raises(KeyError) { CloudflareEmailSmtp.settings }
    assert_match(/CLOUDFLARE_EMAIL_API_TOKEN/, error.message)
  end

  test "production initializer waits for autoload before touching CloudflareEmailSmtp" do
    source = Rails.root.join("config/initializers/cloudflare_email_smtp.rb").read

    assert_includes source, "after_initialize"
    refute_match(/^Rails\.application\.config\.action_mailer\.smtp_settings = CloudflareEmailSmtp/, source)
  end
end
