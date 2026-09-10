# Asset precompile boots production without secrets (`SECRET_KEY_BASE_DUMMY=1`).
return unless Rails.env.production?
return if ENV["SECRET_KEY_BASE_DUMMY"].present?

Rails.application.config.action_mailer.smtp_settings = CloudflareEmailSmtp.settings
