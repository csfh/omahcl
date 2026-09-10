class CloudflareEmailSmtp
  ADDRESS = "smtp.mx.cloudflare.net"
  PORT = 465
  USERNAME = "api_token"

  def self.settings
    {
      address: ADDRESS,
      port: PORT,
      user_name: USERNAME,
      password: ENV.fetch("CLOUDFLARE_EMAIL_API_TOKEN"),
      authentication: :plain,
      tls: true,
      enable_starttls: false,
      enable_starttls_auto: false
    }
  end
end
