# Rails::Rack::Logger puts the client IP on every "Started" line. Logs must not
# identify anyone who uses the site, so log the request without it.
class AnonymousRequestLogger < Rails::Rack::Logger
  private
    def started_request_message(request)
      "Started #{request.raw_request_method} \"#{request.filtered_path}\" at #{Time.now}"
    end
end

Rails.application.config.middleware.swap Rails::Rack::Logger, AnonymousRequestLogger, Rails.application.config.log_tags
