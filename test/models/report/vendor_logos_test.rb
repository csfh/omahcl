require "test_helper"

class Report::VendorLogosTest < ActiveSupport::TestCase
  # The file is built from downloaded SVGs by script/vendor_logos.rb. It is drawn into
  # every page, so keep it to path commands and numbers.
  test "every logo is plain path data under a vendor's own slug" do
    assert_operator Report::Vendor::LOGOS.size, :>=, 10
    Report::Vendor::LOGOS.each do |slug, outline|
      assert_equal slug, Report::Vendor.slug(slug), slug
      assert_match(/\A[MmLlHhVvCcSsQqTtAaZz0-9eE.,\s+-]+\z/, outline, slug)
    end
  end

  test "a vendor is found by any spelling of its name" do
    assert Report::Vendor.logo("Dell")
    assert Report::Vendor.logo(Report::Vendor.canonical("DELL Inc."))
    assert Report::Vendor.logo("MSI")
    assert_nil Report::Vendor.logo("Zed Systems")
    assert_nil Report::Vendor.logo("")
  end
end
