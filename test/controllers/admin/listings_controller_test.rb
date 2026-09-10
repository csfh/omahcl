require "test_helper"

class Admin::ListingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report, token = ingest_report!
    @report.claim!(user: users(:one), token: token)
  end

  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_listings_path
    assert_redirected_to root_path
  end

  test "index includes draft and closed listings" do
    published = Listing.create!(
      report: @report,
      kind: "sale",
      title: "Published X220",
      condition: "used",
      price_amount: "150",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "published"
    )
    published.close!
    other, other_token = ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "b" * 64))
    other.claim!(user: users(:two), token: other_token)
    Listing.create!(
      report: other,
      kind: "sale",
      title: "Draft X230",
      condition: "used",
      price_amount: "200",
      currency: "USD",
      city: "Aarhus",
      country_code: "DK",
      status: "draft"
    )

    sign_in_as(users(:admin))
    get admin_listings_path

    assert_response :success
    assert_select "a", text: "Published X220"
    assert_select "a", text: "Draft X230"
    assert_select "p", /Closed/
    assert_select "p", /Draft/
  end

  test "close redirects to the admin listing" do
    listing = Listing.create!(
      report: @report,
      kind: "sale",
      title: "Used X220",
      condition: "used",
      price_amount: "150",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "published"
    )
    sign_in_as(users(:admin))

    post close_admin_listing_path(listing)

    assert listing.reload.closed?
    assert_redirected_to admin_listing_path(listing)
  end

  test "show tolerates a listing with no owner" do
    listing = Listing.create!(
      report: @report,
      kind: "sale",
      title: "Orphan X220",
      condition: "used",
      price_amount: "150",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "closed"
    )
    @report.update!(user: nil, claimed_at: nil)

    sign_in_as(users(:admin))
    get admin_listing_path(listing)

    assert_response :success
    assert_select "p", /No owner/
  end
end
