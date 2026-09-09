module Me
  class ListingsController < ApplicationController
    before_action :set_report
    before_action :set_listing, only: %i[edit update]

    def new
      if @report.open_listing
        redirect_to edit_me_report_listing_path(@report)
        return
      end
      @listing = @report.listings.build(kind: "sale", currency: "USD", status: "published")
    end

    def create
      @listing = @report.listings.build(listing_params)
      @listing.status = "published"
      if @listing.save
        redirect_to listing_path(@listing), notice: "Listing published."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if params[:close]
        @listing.close!
        redirect_to me_reports_path, notice: "Listing closed."
        return
      end

      if @listing.update(listing_params)
        redirect_to listing_path(@listing), notice: "Listing updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_report
        @report = current_user.reports.find(params[:report_id])
      end

      def set_listing
        @listing = @report.open_listing
        redirect_to new_me_report_listing_path(@report), alert: "No open listing." unless @listing
      end

      def listing_params
        params.require(:listing).permit(
          :kind, :condition, :title, :description, :price_amount, :currency,
          :city, :country_code, :donation_destination_id, photos: []
        )
      end
  end
end
