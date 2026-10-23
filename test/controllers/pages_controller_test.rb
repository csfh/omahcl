require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def chart(id) = "section[aria-labelledby=#{id}]"

  test "the favicon is a digested asset, so a new one reaches returning visitors" do
    get root_path

    hrefs = css_select("link[rel=icon]").map { |link| link["href"] }
    assert_equal 2, hrefs.size
    hrefs.each { |href| assert_match %r{\A/assets/icon-[0-9a-f]+\.(png|svg)\z}, href }

    get hrefs.find { |href| href.end_with?(".svg") }
    assert_response :success
    assert_includes response.body, "#86c5ba"
  end

  test "the head sizes the page to the phone and colors the browser bar" do
    get root_path

    assert_select "meta[name=viewport][content='width=device-width,initial-scale=1']"
    assert_select "meta[name=theme-color][content='#131c1e']"
    assert_no_match(/user-scalable|maximum-scale/, css_select("meta[name=viewport]").first["content"])
  end

  test "home has no dashboard until a machine has reported" do
    get root_path

    assert_response :success
    assert_select "#stats-heading", false
  end

  test "home charts the machines people reported" do
    3.times { ingest_report!(omarchy_payload) }

    get root_path

    assert_response :success
    assert_select "#stats-heading", "Machines on record"
    assert_select "dl dd", text: "3"
    assert_select "#{chart('stats-vendor')} li", text: /Lenovo.*3/m
    assert_select "#{chart('stats-memory')} li", 6
    assert_select "#{chart('stats-security')} li", text: /UEFI.*100%/m
    assert_select "#{chart('stats-gpu')} li", text: /Intel.*3/m
  end

  test "architecture is its own chart, and the version chart is just Version" do
    ingest_report!

    get root_path

    assert_select "#stats-architecture", "Architecture"
    assert_select "#{chart('stats-architecture')} li", text: /x86_64.*1/m
    assert_select "#stats-version", "Version"
    assert_select "dt", text: "Versions"
    assert_select "#{chart('stats-channel')} li", text: /stable.*1/m
    assert_select "#stats-cpu ~ p", text: /Architecture/, count: 0
  end

  test "charts are drawn as text with an aria-hidden SVG and no inline styles" do
    ingest_report!

    get root_path

    assert_select "#{chart('stats-vendor')} li svg[aria-hidden=true] rect", 14
    assert_select "#{chart('stats-vendor')} li svg title", text: "Lenovo: 1"
    assert_select "#main [style]", false
  end

  test "hidden machines are not charted" do
    ingest_report!.update!(hidden_at: Time.current)

    get root_path

    assert_select "#stats-heading", false
  end

  test "growth shows as a table behind the columns once there are two weeks" do
    travel_to(2.weeks.ago) { ingest_report! }
    ingest_report!

    get root_path

    assert_select "#stats-growth"
    assert_select "#{chart('stats-growth')} .sr-only table tbody tr", 3
  end

  test "the report panel leads with a real card and keeps the caution under it" do
    report = ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    get root_path

    assert_select ".hero p", text: "Report your machine and get a card like this."
    assert_select ".hero a[href=?] img[src=?][width='1200'][height='630']", card_path(report.card_key), card_path(report.card_key, format: :png)
    assert_select ".hero p", text: "Run this in a terminal. It sends nothing unless you say yes."
    assert_select ".hero p", text: /Run it again after an Omarchy update to refresh the version on your card/
    assert_select "#report p", text: /Run it again after an Omarchy update/
    assert_select "header nav a[href=?]", root_path(anchor: "report"), text: "Get your card"
  end

  test "the report panel has no card to show before the first report" do
    get root_path

    assert_select ".hero img", count: 0
    assert_select ".hero p", text: "Report your machine and get an Omarchy Verified card."
  end

  test "the card shown is the most reported configuration" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "1" * 64))
    busy = ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "2" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "3" * 64))

    get root_path

    assert_select ".hero img[src=?]", card_path(busy.card_key, format: :png)
  end

  test "just reported lists the newest models once each, with how long ago" do
    old = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "1" * 64))
    old.update_columns(created_at: 3.days.ago)
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "2" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "3" * 64))

    get root_path

    assert_select "#just-reported"
    assert_select "section[aria-labelledby=just-reported] li", 2
    assert_select "section[aria-labelledby=just-reported] li:first-child", text: /ThinkPad X230.*less than a minute ago/m
    assert_select "section[aria-labelledby=just-reported] li:last-child", text: /ThinkPad X220.*3 days ago/m
  end

  test "just reported leaves out hidden machines and is absent when empty" do
    get root_path
    assert_select "#just-reported", count: 0

    ingest_report!(omarchy_payload(product: "ThinkPad X220")).update!(hidden_at: Time.current)
    get root_path
    assert_select "#just-reported", count: 0
  end

  test "the home page shows the top three vendors as a podium with their logos" do
    3.times { |i| ingest_report!(omarchy_payload(product: "XPS #{i}", instance_digest: "a#{i}" + "0" * 62).deep_merge("hardware" => { "vendor" => "Dell Inc." })) }
    2.times { |i| ingest_report!(omarchy_payload(product: "T#{i}", instance_digest: "b#{i}" + "0" * 62)) }
    ingest_report!(omarchy_payload(product: "Air", instance_digest: "c" * 64).deep_merge("hardware" => { "vendor" => "Apple Inc." }))
    ingest_report!(omarchy_payload(product: "Box", instance_digest: "d" * 64).deep_merge("hardware" => { "vendor" => "Zed Systems" }))

    get root_path

    assert_select "ol[aria-label='Most reported vendors'] li", 3
    assert_select "ol[aria-label='Most reported vendors'] li:nth-child(1) a[href=?][aria-label^='Dell, first place, 3 machines']", vendor_path("dell")
    assert_select "ol[aria-label='Most reported vendors'] li:nth-child(1).order-2 svg path[d]"
    assert_select "ol[aria-label='Most reported vendors'] li:nth-child(2).order-1 a[href=?]", vendor_path("lenovo")
    assert_select "ol[aria-label='Most reported vendors'] li:nth-child(3).order-3 a[href=?][aria-label^='Apple, third place']", vendor_path("apple")
    assert_select "ol[aria-label='Most reported vendors'] a[href=?]", vendor_path("zed-systems"), count: 0
  end

  test "vendors with the same count stand level on the podium, and one without a logo shows its initial" do
    ingest_report!(omarchy_payload(product: "Box", instance_digest: "1" * 64).deep_merge("hardware" => { "vendor" => "Zed Systems" }))
    ingest_report!(omarchy_payload(product: "T1", instance_digest: "2" * 64))

    get root_path

    assert_select "ol[aria-label='Most reported vendors'] li", 2
    assert_select "ol[aria-label='Most reported vendors'] li a[aria-label*='first place']", 2
    assert_select "ol[aria-label='Most reported vendors'] li a[href=?] .font-pixel", vendor_path("zed-systems"), text: "Z"
  end

  test "there is no podium before the first report" do
    get root_path

    assert_select "ol[aria-label='Most reported vendors']", count: 0
  end

  test "the copy button stretches to the height of the command" do
    get root_path

    assert_select "[data-controller=clipboard].items-stretch button.justify-center", text: /Copy/
    assert_select ".hero h2", text: "Get your card"
  end

  test "the layout keeps the phone header on two rows and the footer legible" do
    get root_path

    assert_select "header nav.w-full.justify-between"
    assert_select "footer p.w-full", text: /Unofficial community database/
    assert_select "footer a", count: 2
  end

  test "privacy points to deleting a report near the top and explains how" do
    get privacy_path

    assert_response :success
    assert_select "article > p a[href='#deleting']", text: "delete your report"
    assert_select "h2#deleting", text: "Deleting your report"
    assert_select "code", text: /\/delete \| bash/
  end
end
