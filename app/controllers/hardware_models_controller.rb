class HardwareModelsController < ApplicationController
  allow_unauthenticated_access

  before_action :load_model, only: %i[show card]

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

  def card
    respond_to do |format|
      format.html
      format.png do
        return unless stale?(etag: [ "card-png-2", @card.except(:machines) ], public: true)

        expires_in 1.hour, public: true
        send_data CardImage.new(**@card.except(:machines)).png, type: "image/png", disposition: "inline"
      end
    end
  end

  private

  def load_model
    @reports = Report.visible.where(model_slug: params[:slug]).order(created_at: :desc)
    raise ActiveRecord::RecordNotFound if @reports.empty?

    @sample = @reports.first
    @machines_count = @reports.unscope(:order).distinct.count(:instance_digest)
    @cpu_models = @reports.unscope(:order).distinct.pluck(:cpu_model)
    @gpus = @reports.flat_map { |report| report.gpus }.uniq
    @card = {
      name: @sample.display_name,
      cpu: @cpu_models.first,
      gpu: @gpus.map { |gpu| [ gpu["vendor"], gpu["name"] ].compact.join(" ") }.first.presence || "None reported",
      version: @sample.omarchy_version.presence || "Unknown",
      machines: @machines_count
    }
  end
end
