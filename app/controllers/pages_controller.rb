class PagesController < ApplicationController
  allow_unauthenticated_access

  def home
    @query = params[:q].to_s
    @models = Report.grouped_models(@query).limit(12)
    @stats = Report::Stats.new
  end

  def privacy
  end
end
