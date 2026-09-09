require "test_helper"

class ListingTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @report, token = ingest_report!
    @report.claim!(user: @user, token: token)
    @destination = DonationDestination.create!(
      name: "Omacom Foundation",
      url: "https://donate.omarchy.org",
      active: true
    )
  end

  test "sale listing requires price condition and location" do
    listing = Listing.new(report: @report, kind: "sale", title: "X220", status: "published")

    refute listing.valid?
    assert_includes listing.errors.attribute_names, :price_cents
    assert_includes listing.errors.attribute_names, :condition
  end

  test "sale listing is valid with price in dollars" do
    listing = Listing.new(
      report: @report,
      kind: "sale",
      title: "ThinkPad X220",
      condition: "used",
      price_amount: "120.00",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "published"
    )

    assert listing.valid?
    assert_equal 12000, listing.price_cents
  end

  test "donation listing requires an active destination" do
    listing = Listing.new(
      report: @report,
      kind: "donation",
      title: "Give this X220",
      status: "published"
    )

    refute listing.valid?

    listing.donation_destination = @destination
    assert listing.valid?
  end

  test "a report may only have one open listing" do
    Listing.create!(
      report: @report,
      kind: "donation",
      title: "Give this X220",
      donation_destination: @destination,
      status: "published"
    )

    duplicate = Listing.new(
      report: @report,
      kind: "sale",
      title: "Sell it",
      condition: "used",
      price_amount: "10",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "published"
    )

    refute duplicate.valid?
  end
end
