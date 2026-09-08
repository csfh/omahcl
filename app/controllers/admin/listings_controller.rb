module Admin
  class ListingsController < BaseController
    def close
      listing = Listing.find(params[:id])
      listing.close!
      redirect_to listings_path, notice: "Listing closed."
    end
  end
end
