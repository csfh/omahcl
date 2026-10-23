class HardwareModelsController < ApplicationController
  allow_unauthenticated_access

  before_action :load_model, only: :show

  def index
    # /models?vendor= was the vendor leaderboard for a day before it got its own page.
    slug = Report::Vendor.slug(params[:vendor])
    return redirect_to(vendor_path(slug), status: :moved_permanently) if slug.present?

    @query = params[:q].to_s
    @models, @close = search(@query)
  end

  def suggestions
    @query = params[:q].to_s.strip
    @models = @query.present? ? search(@query).first.limit(8) : []
    render layout: false
  end

  def show
    @stats = Report::Stats.new(@reports.unscope(:order))
  end

  private

  # Exact matches, or failing those the close ones. Returns the models and whether they
  # are only close.
  def search(query)
    exact = Report.grouped_models(query)
    return [ exact, false ] if query.blank? || exact.exists?

    close = Report.grouped_models(query, fuzzy: true)
    close.exists? ? [ close, true ] : [ exact, false ]
  end

  def load_model
    @reports = Report.visible.where(model_slug: params[:slug]).order(created_at: :desc)
    raise ActiveRecord::RecordNotFound if @reports.empty?

    @sample = @reports.first
    @machines_count = @reports.unscope(:order).distinct.count(:instance_digest)
    @cpu_models = @reports.unscope(:order).distinct.pluck(:cpu_model).map { |cpu| Report::Display.cpu(cpu) }.uniq
    @gpus = Report::Display.gpus(@reports.flat_map { |report| report.gpus }.uniq)
    @cards = @reports.unscope(:order).group(:card_key).order(Arel.sql("MAX(cpu_model)")).pluck(:card_key, Arel.sql("MAX(cpu_model)"))
      .map { |key, cpu| [ key, Report::Display.cpu(cpu) ] }
  end
end
