# Be sure to restart your server when you modify this file.

# Scripts may run inline and load from this site or Cloudflare. Cloudflare injects
# an inline bot-detection script whose text changes on every response, and Turbo
# re-runs it with the next response's nonce, which the page's policy rejects. So
# script-src allows 'unsafe-inline' and carries no nonce: browsers ignore
# 'unsafe-inline' while one is present. The hosts are the ones Cloudflare lists for
# its features:
# https://developers.cloudflare.com/fundamentals/reference/policies-compliances/content-security-policies/
# https://developers.cloudflare.com/turnstile/reference/content-security-policy/
# See the Securing Rails Applications Guide:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, :unsafe_inline, "https://ajax.cloudflare.com",
      "https://static.cloudflareinsights.com", "https://challenges.cloudflare.com"
    policy.style_src :self
    policy.img_src :self
    policy.font_src :self
    policy.connect_src :self, "https://cloudflareinsights.com"
    policy.frame_src :self, "https://challenges.cloudflare.com"
    policy.manifest_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # A fresh nonce per response. Rails' example derives it from the session id,
  # which would set a session cookie on every page.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[style-src]
end
