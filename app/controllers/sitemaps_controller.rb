# Public pages for search engines: home, the lists, and one page per model. Hidden
# machines are left out, and a model whose every machine is hidden has no page.
class SitemapsController < ApplicationController
  allow_unauthenticated_access

  def show
    @models = Report.visible.group(:model_slug).maximum(:updated_at).sort
    expires_in 1.hour, public: true
    respond_to { |format| format.xml }
  end
end
