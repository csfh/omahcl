require "test_helper"

class Report::VendorTest < ActiveSupport::TestCase
  test "spacing, case and corporate suffixes do not make a new vendor" do
    [ "Dell Inc.", "Dell  Inc.", " DELL INC ", "Dell Inc", "Dell" ].each do |raw|
      assert_equal "Dell", Report::Vendor.canonical(raw), raw.inspect
    end
  end

  test "known manufacturers get their brand name" do
    {
      "LENOVO" => "Lenovo",
      "Micro-Star International Co., Ltd." => "MSI",
      "ASUSTeK COMPUTER INC." => "ASUS",
      "Gigabyte Technology Co., Ltd." => "Gigabyte",
      "SAMSUNG ELECTRONICS CO., LTD." => "Samsung",
      "Apple Inc." => "Apple",
      "Hewlett-Packard" => "HP",
      "HP Inc." => "HP",
      "Microsoft Corporation" => "Microsoft",
      "ASRock" => "ASRock"
    }.each do |raw, brand|
      assert_equal brand, Report::Vendor.canonical(raw), raw
    end
  end

  test "an unknown vendor keeps its spelling, minus spacing and suffix" do
    assert_equal "SLIMBOOK", Report::Vendor.canonical("SLIMBOOK")
    assert_equal "Tuxedo Computers", Report::Vendor.canonical("Tuxedo  Computers GmbH")
  end

  test "a vendor that is only a corporate suffix is kept" do
    assert_equal "Inc.", Report::Vendor.canonical("Inc.")
  end

  test "ingest stores the canonical vendor, so spellings share one model" do
    first = ingest_report!(omarchy_payload(product: "XPS 13").deep_merge("hardware" => { "vendor" => "Dell Inc." }))
    second = ingest_report!(omarchy_payload(product: "XPS  13").deep_merge("hardware" => { "vendor" => "Dell  Inc." }))

    assert_equal "Dell", second.vendor
    assert_equal "XPS 13", second.product
    assert_equal "dell|xps 13", first.model_key
    assert_equal first.model_key, second.model_key
    assert_equal first.model_slug, second.model_slug
    assert_equal first.card_key, second.card_key
    assert_equal "Dell Inc.", first.facts.dig("hardware", "vendor")
    assert_equal 1, Report.grouped_models.to_a.size
  end
end
