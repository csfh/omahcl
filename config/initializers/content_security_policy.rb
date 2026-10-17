# Be sure to restart your server when you modify this file.

# Everything the site loads comes from its own origin, so the policy is
# same-origin only. Cloudflare's bot detection loads from /cdn-cgi/challenge-platform/
# on this origin, and Cloudflare copies the nonce from this header onto the inline
# script it injects. See the Securing Rails Applications Guide:
# https://guides.rubyonrails.org/security.html#content-security-policy-header
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self
    policy.style_src :self
    policy.img_src :self
    policy.font_src :self
    policy.connect_src :self
    policy.manifest_src :self
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # A fresh nonce per response. Rails' example derives it from the session id,
  # which would set a session cookie on every page.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
