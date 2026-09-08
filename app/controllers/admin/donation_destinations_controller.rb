module Admin
  class DonationDestinationsController < BaseController
    before_action :set_destination, only: %i[edit update destroy]

    def index
      @destinations = DonationDestination.order(:name)
    end

    def new
      @destination = DonationDestination.new
    end

    def create
      @destination = DonationDestination.new(destination_params)
      if @destination.save
        redirect_to admin_donation_destinations_path, notice: "Destination added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @destination.update(destination_params)
        redirect_to admin_donation_destinations_path, notice: "Destination updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @destination.destroy!
      redirect_to admin_donation_destinations_path, notice: "Destination removed."
    rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::DeleteRestrictionError
      redirect_to admin_donation_destinations_path, alert: "This destination still has listings."
    end

    private
      def set_destination
        @destination = DonationDestination.find(params[:id])
      end

      def destination_params
        params.require(:donation_destination).permit(:name, :url, :description, :active)
      end
  end
end
