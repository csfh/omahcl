require "test_helper"

class ListingsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @destination = DonationDestination.create!(
      name: "Omacom Foundation",
      url: "https://donate.omarchy.org",
      active: true
    )
    @user = users(:one)
    @report, token = ingest_report!
    @report.claim!(user: @user, token: token)
  end

  test "owner publishes a sale listing" do
    sign_in_as(@user)

    assert_difference -> { Listing.count }, 1 do
      post me_report_listing_path(@report), params: {
        listing: {
          kind: "sale",
          title: "Used X220",
          condition: "used",
          price_amount: "150",
          currency: "USD",
          city: "Copenhagen",
          country_code: "DK"
        }
      }
    end

    listing = Listing.last
    assert_redirected_to listing_path(listing)
    follow_redirect!
    assert_response :success
    assert_select "h1", "Used X220"
    assert_select "p", /For sale/
    assert_select "a", text: "Omarchy on this machine"
  end

  test "listings index uses product language" do
    Listing.create!(
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

    get listings_path

    assert_response :success
    assert_select "h1", "Machines for sale or donation"
    assert_select "p", /People sell or give machines here/
    assert_select "li p", /For sale/
  end

  test "owner publishes a donation listing" do
    sign_in_as(@user)

    post me_report_listing_path(@report), params: {
      listing: {
        kind: "donation",
        title: "X220 for the foundation",
        donation_destination_id: @destination.id
      }
    }

    listing = Listing.last
    assert listing.donation?
    assert_equal @destination, listing.donation_destination
  end

  test "admin can close a listing" do
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

  test "strangers cannot list someone else's report" do
    sign_in_as(users(:two))

    post me_report_listing_path(@report), params: {
      listing: { kind: "donation", title: "Nope", donation_destination_id: @destination.id }
    }

    assert_response :not_found
  end
end
