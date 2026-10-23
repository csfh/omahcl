class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @query = params[:q].to_s
    @models = Report.grouped_models(@query).limit(12)
    @stats = Report::Stats.new
    @featured_card = Report.featured_card
    @recent_models = Report.recent_models
  end

  def privacy
  end
end
