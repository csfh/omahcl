# The Omarchy Verified card for one configuration: a model with one CPU. Anyone
# with the link can open it, and it shows only what the model page already shows.
class CardsController < ApplicationController
  allow_unauthenticated_access

  def show
    reports = Report.visible.where(card_key: params[:key]).order(created_at: :desc)
    raise ActiveRecord::RecordNotFound if reports.empty?

    @sample = reports.first
    @machines_count = reports.unscope(:order).distinct.count(:instance_digest)
    gpus = reports.flat_map { |report| report.gpus }.uniq
    @card = {
      name: @sample.display_name,
      cpu: Report::Display.cpu(@sample.cpu_model),
      gpu: Report::Display.gpus(gpus).first || "None reported",
      version: @sample.omarchy_version.presence || "Unknown"
    }

    respond_to do |format|
      format.html
      format.png do
        return unless stale?(etag: [ "card-png-3", @card ], public: true)

        expires_in 1.hour, public: true
        # The picture has room for about 22 characters a line, so it gets the short names.
        short = @card.merge(
          name: Report::Display.model(@sample.vendor, @sample.product, @sample.family, short: true),
          cpu: Report::Display.cpu(@sample.cpu_model, short: true),
          gpu: Report::Display.gpus(gpus, short: true).first || "None reported"
        )
        send_data CardImage.new(**short).png, type: "image/png", disposition: "inline", filename: "#{params[:key]}.png"
      end
    end
  end
end
