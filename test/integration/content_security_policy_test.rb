require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages allow inline scripts and Cloudflare's script hosts" do
    get root_path

    policy = response.headers["Content-Security-Policy"].to_s
    nonce = policy[/style-src [^;]*'nonce-([^']+)'/, 1]

    # Browsers ignore 'unsafe-inline' while script-src carries a nonce or hash.
    assert_equal "script-src 'self' 'unsafe-inline' https://ajax.cloudflare.com " \
      "https://static.cloudflareinsights.com https://challenges.cloudflare.com", policy[/script-src [^;]*/]
    assert nonce, "style-src carries a nonce: #{policy}"
    assert_includes policy, "style-src 'self' 'nonce-#{nonce}'"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "connect-src 'self' https://cloudflareinsights.com"
    assert_includes policy, "frame-src 'self' https://challenges.cloudflare.com"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "form-action 'self'"
    assert_includes policy, "frame-ancestors 'none'"
  end

  test "each response gets its own style nonce, without a session cookie" do
    get root_path
    first = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    get root_path
    second = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]

    refute_equal first, second
    assert_nil response.headers["Set-Cookie"]
  end
end
