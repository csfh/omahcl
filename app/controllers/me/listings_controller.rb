module Me
  class ListingsController < ApplicationController
    before_action :set_machine
    before_action :set_listing, only: %i[edit update]

    def new
      if @machine.open_listing
        redirect_to edit_me_machine_listing_path(@machine)
        return
      end
      @listing = @machine.listings.build(kind: "sale", currency: "USD", status: "published")
    end

    def create
      @listing = @machine.listings.build(listing_params)
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
        redirect_to me_machines_path, notice: "Listing closed."
        return
      end

      if @listing.update(listing_params)
        redirect_to listing_path(@listing), notice: "Listing updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private
      def set_machine
        @machine = current_user.machines.find(params[:machine_id])
      end

      def set_listing
        @listing = @machine.open_listing
        redirect_to new_me_machine_listing_path(@machine), alert: "No open listing." unless @listing
      end

      def listing_params
        params.require(:listing).permit(
          :kind, :condition, :title, :description, :price_amount, :currency,
          :city, :country_code, :donation_destination_id, photos: []
        )
      end
  end
end
