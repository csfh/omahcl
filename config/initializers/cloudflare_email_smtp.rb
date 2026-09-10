# Asset precompile boots production without secrets (`SECRET_KEY_BASE_DUMMY=1`).
# Wait until after initialize so Zeitwerk has loaded app/models during db:prepare.
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  next if ENV["SECRET_KEY_BASE_DUMMY"].present?

  settings = CloudflareEmailSmtp.settings
  Rails.application.config.action_mailer.smtp_settings = settings
  ActionMailer::Base.smtp_settings = settings
end
