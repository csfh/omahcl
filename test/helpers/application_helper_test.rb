require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "people_ran_omarchy uses spoken person counts" do
    assert_equal "1 person has run Omarchy on this machine.", people_ran_omarchy(1)
    assert_equal "3 people have run Omarchy on this machine.", people_ran_omarchy(3)
  end

  test "listing_kind_label names the offer" do
    sale = Listing.new(kind: "sale")
    donation = Listing.new(kind: "donation")

    assert_equal "For sale", listing_kind_label(sale)
    assert_equal "Donation", listing_kind_label(donation)
  end
end
