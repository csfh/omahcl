require "test_helper"

class Admin::DonationDestinationsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_donation_destinations_path
    assert_redirected_to root_path
  end

  test "admin can create a destination" do
    sign_in_as(users(:admin))

    assert_difference -> { DonationDestination.count }, 1 do
      post admin_donation_destinations_path, params: {
        donation_destination: {
          name: "Local lab",
          url: "https://example.org/donate",
          active: true
        }
      }
    end

    assert_redirected_to admin_donation_destinations_path
  end
end
