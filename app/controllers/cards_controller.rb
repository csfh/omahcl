# The Omarchy Verified card for one configuration: a model with one CPU. Anyone
# with the link can open it, and it shows only what the model page already shows.
class CardsController < ApplicationController
  allow_unauthenticated_access

  def show
    reports = Report.visible.where(card_key: params[:key]).order(created_at: :desc)
    raise ActiveRecord::RecordNotFound if reports.empty?

    @sample = reports.first
    @machines_count = reports.unscope(:order).distinct.count(:instance_digest)
    @card = {
      name: @sample.display_name,
      cpu: @sample.cpu_model,
      gpu: reports.flat_map { |report| report.gpus }.uniq.map { |gpu| [ gpu["vendor"], gpu["name"] ].compact.join(" ") }.first.presence || "None reported",
      version: @sample.omarchy_version.presence || "Unknown"
    }

    respond_to do |format|
      format.html
      format.png do
        return unless stale?(etag: [ "card-png-2", @card ], public: true)

        expires_in 1.hour, public: true
        send_data CardImage.new(**@card).png, type: "image/png", disposition: "inline", filename: "#{params[:key]}.png"
      end
    end
  end
end
