class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @query = params[:q].to_s
    @models = Report.grouped_models(@query).limit(12)
    @listings = Listing.visible.order(created_at: :desc).limit(8)
  end

  def privacy
  end
end
