require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "pages send a same-origin policy whose nonce covers the page's own scripts" do
    get root_path

    policy = response.headers["Content-Security-Policy"].to_s
    nonce = policy[/'nonce-([^']+)'/, 1]

    assert nonce, "script-src carries a nonce: #{policy}"
    assert_includes policy, "default-src 'self'"
    assert_includes policy, "script-src 'self' 'nonce-#{nonce}'"
    assert_includes policy, "style-src 'self' 'nonce-#{nonce}'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "form-action 'self'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_select "script[type=importmap][nonce=?]", nonce
    assert_select "script[type=module][nonce=?]", nonce
    assert_select "meta[name=csp-nonce][content=?]", nonce
  end

  # Cloudflare copies the nonce from this header onto the bot-detection script it
  # injects, so the header must carry it rather than a meta tag.
  test "each response gets its own nonce, without a session cookie" do
    get root_path
    first = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]
    get root_path
    second = response.headers["Content-Security-Policy"][/'nonce-([^']+)'/, 1]

    refute_equal first, second
    assert_nil response.headers["Set-Cookie"]
  end
end
