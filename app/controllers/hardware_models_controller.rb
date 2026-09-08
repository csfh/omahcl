class HardwareModelsController < ApplicationController
  allow_unauthenticated_access

  def index
    @query = params[:q].to_s
    @models = Report.grouped_models(@query)
  end

  def show
    @reports = Report.where(model_slug: params[:slug]).order(created_at: :desc)
    raise ActiveRecord::RecordNotFound if @reports.empty?

    @sample = @reports.first
    @listings = Listing.visible.for_model(params[:slug]).order(created_at: :desc)
    @cpu_models = @reports.unscope(:order).distinct.pluck(:cpu_model)
    @gpus = @reports.flat_map { |report| report.gpus }.uniq
    @versions = @reports.unscope(:order).distinct.pluck(:omarchy_version)
  end
end
