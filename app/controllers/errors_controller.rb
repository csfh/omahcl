# The branded 404, rendered by config.exceptions_app for unknown routes and for models
# and cards that do not exist. It queries no reports, so it still answers when they
# cannot be read. Anything but an HTML request, such as a card PNG or JSON, gets a bare
# 404: there is no template for those formats and a missing one would be a 500.
class ErrorsController < ApplicationController
  allow_unauthenticated_access

  def not_found
    @canonical = false
    respond_to do |format|
      format.html do
        @query = Report::Vendor.query_from_slug(request.env["action_dispatch.original_path"].to_s[%r{\A/models/([^/?.]+)}, 1])
        render status: :not_found
      end
      format.any { head :not_found }
    end
  end
end
