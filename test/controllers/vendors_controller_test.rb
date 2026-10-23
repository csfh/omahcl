require "test_helper"

class VendorsControllerTest < ActionDispatch::IntegrationTest
  test "a vendor's page ranks its models by machines and says where the vendor stands" do
    3.times { |i| ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "a#{i}" + "0" * 62)) }
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "b" * 64))
    ingest_report!(omarchy_payload(product: "XPS 13", instance_digest: "c" * 64).deep_merge("hardware" => { "vendor" => "Dell Inc.", "family" => "XPS" }))

    get vendor_path("lenovo")

    assert_response :success
    assert_select "h1", "Lenovo on Omarchy"
    assert_select "h1 svg path[d]"
    assert_select "link[rel=canonical][href=?]", "http://www.example.com/vendors/lenovo"
    assert_select "p", text: /The most reported vendor\. 4 machines reported/
    assert_select "ol li:nth-child(1) a", text: /X230/
    assert_select "ol li:nth-child(2) a", text: /X220/
    assert_select "ol li:nth-child(1) .tabular-nums", text: /1/
    assert_select "a", text: /XPS/, count: 0

    get vendor_path("dell")
    assert_select "p", text: /Number 2 of 2 vendors/
  end

  test "models with the same count share a rank and tied vendors say so" do
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "1" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "2" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "3" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad T420", instance_digest: "4" * 64))
    %w[5 6 7 8].each { |d| ingest_report!(omarchy_payload(product: "XPS #{d}", instance_digest: d * 64).deep_merge("hardware" => { "vendor" => "Dell Inc." })) }

    get vendor_path("lenovo")

    assert_select "ol li .tabular-nums", text: /\A\s*(Number )?1\s*\z/, count: 1
    assert_select "ol li .tabular-nums", text: /\A\s*(Number )?2\s*\z/, count: 2
    assert_select "ol li .tabular-nums", text: /3/, count: 0
    assert_select "p", text: /Tied for most reported vendor\. 4 machines/
  end

  test "an unknown vendor is not found, and a vendor with only hidden machines has no page" do
    ingest_report!(omarchy_payload(instance_digest: "1" * 64).deep_merge("hardware" => { "vendor" => "Dell Inc." })).update!(hidden_at: Time.current)

    get vendor_path("no-such-vendor")
    assert_response :not_found

    get vendor_path("dell")
    assert_response :not_found
  end

  test "every vendor on the chart reaches its own page by the one slug function" do
    [ "Dell Inc.", "To Be Filled By O.E.M.", "Micro-Star International Co., Ltd.", "System76" ].each_with_index do |vendor, i|
      ingest_report!(omarchy_payload(product: "Box #{i}", instance_digest: i.to_s * 64).deep_merge("hardware" => { "vendor" => vendor }))
    end

    Report::Stats.new.vendors.each do |row|
      get vendor_path(Report::Vendor.slug(row.label))
      assert_response :success, row.label
      assert_select "h1", "#{row.label} on Omarchy"
    end
  end

  test "a vendor name the route cannot hold does not break the home page, sitemap or model pages" do
    [ "Acme_Corp", "Acme  Corp!", "华硕", "!!!", "_Under_" ].each_with_index do |vendor, i|
      2.times { |n| ingest_report!(omarchy_payload(product: "Box #{i}", instance_digest: "#{i}#{n}" + "0" * 62).deep_merge("hardware" => { "vendor" => vendor })) }
    end

    { "Acme_Corp" => "acme-corp", "_Under_" => "under", "华硕" => "", "!!!" => "", "Dell  Inc." => "dell" }.each do |name, slug|
      assert_equal slug, Report::Vendor.slug(Report::Vendor.canonical(name)), name
    end

    get root_path
    assert_response :success
    assert_select "ol[aria-label='Most reported vendors'] li", 3
    get sitemap_path(format: :xml)
    assert_response :success
    urls = Nokogiri::XML(response.body).remove_namespaces!.xpath("//url/loc").map(&:text)
    assert_includes urls, vendor_url("acme-corp")
    assert_includes urls, vendor_url("under")
    assert urls.none? { |url| url.end_with?("/vendors/") }

    Report.find_each do |report|
      get hardware_model_path(report.model_slug)
      assert_response :success, report.vendor
    end
    get vendor_path("acme-corp")
    assert_response :success
  end

  test "the vendor chart links each vendor row to its page, but not the Other row" do
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "1" * 64))

    get root_path

    assert_select "#stats-vendor ~ ul li a[href=?][aria-label^='Lenovo, 1']", vendor_path("lenovo")
    assert_select "#stats-vendor ~ ul li a", count: 1
  end

  test "a model page links to its vendor" do
    report = ingest_report!(omarchy_payload(product: "ThinkPad X230"))

    get hardware_model_path(report.model_slug)

    assert_select "a[href=?]", vendor_path("lenovo"), text: "More from Lenovo"
  end
end
