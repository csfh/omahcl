# One vendor's leaderboard: its models by distinct machines, and where the vendor
# stands among all vendors.
class VendorsController < ApplicationController
  allow_unauthenticated_access

  def show
    vendors = Report::Stats.new.vendors
    @vendor = vendors.find { |row| Report::Vendor.slug(row.label) == params[:slug] }
    raise ActiveRecord::RecordNotFound unless @vendor

    # Competition ranking: vendors with the same count share a rank.
    @rank = vendors.count { |other| other.count > @vendor.count } + 1
    @tied = vendors.count { |other| other.count == @vendor.count } > 1
    @vendors_count = vendors.size
    @models = Report.grouped_models(vendor: @vendor.label)
  end
end
