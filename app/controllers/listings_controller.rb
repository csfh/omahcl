class ListingsController < ApplicationController
  allow_unauthenticated_access

  def index
    @listings = Listing.visible.order(created_at: :desc)
    @listings = @listings.where(kind: params[:kind]) if params[:kind].in?(%w[sale donation])
  end

  def show
    @listing = Listing.visible.find(params[:id])
  end
end
