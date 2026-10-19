class HardwareModelsController < ApplicationController
  allow_unauthenticated_access

  before_action :load_model, only: :show

  def index
    @query = params[:q].to_s
    @models = Report.grouped_models(@query)
  end

  def suggestions
    @query = params[:q].to_s.strip
    @models = @query.present? ? Report.grouped_models(@query).limit(8) : []
    render layout: false
  end

  def show
    @networks_count = @reports.unscope(:order).distinct.count(:submitted_ip_digest)
    @stats = Report::Stats.new(@reports.unscope(:order))
  end

  private

  def load_model
    @reports = Report.visible.where(model_slug: params[:slug]).order(created_at: :desc)
    raise ActiveRecord::RecordNotFound if @reports.empty?

    @sample = @reports.first
    @machines_count = @reports.unscope(:order).distinct.count(:instance_digest)
    @cpu_models = @reports.unscope(:order).distinct.pluck(:cpu_model)
    @gpus = @reports.flat_map { |report| report.gpus }.uniq
    @cards = @reports.unscope(:order).group(:card_key).order(Arel.sql("MAX(cpu_model)")).pluck(:card_key, Arel.sql("MAX(cpu_model)"))
  end
end
