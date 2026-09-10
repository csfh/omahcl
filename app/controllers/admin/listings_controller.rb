module Admin
  class ListingsController < BaseController
    before_action :set_listing, only: %i[show close]

    def index
      @status = params[:status] if params[:status].in?(Listing.statuses.keys)
      @kind = params[:kind] if params[:kind].in?(Listing.kinds.keys)
      @listings = Listing.includes(:report, :donation_destination, report: :user).order(created_at: :desc)
      @listings = @listings.where(status: @status) if @status
      @listings = @listings.where(kind: @kind) if @kind
    end

    def show
    end

    def close
      @listing.close!
      redirect_to admin_listing_path(@listing), notice: "Listing closed."
    end

    private
      def set_listing
        @listing = Listing.find(params[:id])
      end
  end
end
