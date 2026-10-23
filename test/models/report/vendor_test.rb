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

  test "an old model address becomes a search for the model's current name" do
    {
      "dell-inc-xps-14-da14260" => "Dell xps 14 da14260",
      "dell-inc-dell-pro-14-pc14255" => "Dell dell pro 14 pc14255",
      "micro-star-international-co-ltd-ms-7d25" => "MSI ms 7d25",
      "asustek-computer-inc-x510uqr" => "ASUS x510uqr",
      "samsung-electronics-co-ltd-550xda" => "Samsung 550xda",
      "lenovo-20xxs2xu00" => "Lenovo 20xxs2xu00",
      "framework-laptop-13" => "Framework laptop 13",
      "something-unknown-9" => "something unknown 9"
    }.each { |slug, query| assert_equal query, Report::Vendor.query_from_slug(slug), slug }
    assert_nil Report::Vendor.query_from_slug(nil)
    assert_nil Report::Vendor.query_from_slug("")
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
