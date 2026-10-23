class HardwareModelsController < ApplicationController
  allow_unauthenticated_access

  before_action :load_model, only: :show

  def index
    @query = params[:q].to_s
    @vendor = params[:vendor].to_s.strip.presence
    @models = Report.grouped_models(@query, vendor: @vendor)
    load_vendor_rank if @vendor
  end

  def suggestions
    @query = params[:q].to_s.strip
    @models = @query.present? ? Report.grouped_models(@query).limit(8) : []
    render layout: false
  end

  def show
    @stats = Report::Stats.new(@reports.unscope(:order))
  end

  private

  # Where a vendor stands among all vendors by distinct machines, for its leaderboard.
  def load_vendor_rank
    vendors = Report::Stats.new.vendors
    row = vendors.find { |candidate| candidate.label.casecmp?(@vendor) }
    return unless row

    # Competition ranking: vendors with the same count share a rank.
    @vendor_row = row
    @vendor_rank = vendors.count { |other| other.count > row.count } + 1
    @vendor_tied = vendors.count { |other| other.count == row.count } > 1
    @vendors_count = vendors.size
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
