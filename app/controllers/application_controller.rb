class ApplicationController < ActionController::Base
  include Authentication
  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def reject_oversized_body
      head :content_too_large if request.content_length.to_i > 64.kilobytes
    end
end
