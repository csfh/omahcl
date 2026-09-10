class ListingsController < ApplicationController
  allow_unauthenticated_access

  def index
    @kind = params[:kind] if params[:kind].in?(%w[sale donation])
    @listings = Listing.visible.order(created_at: :desc)
    @listings = @listings.where(kind: @kind) if @kind
  end

  def show
    @listing = Listing.visible.find(params[:id])
  end
end
