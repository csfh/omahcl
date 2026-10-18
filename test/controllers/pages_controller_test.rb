require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  def chart(id) = "section[aria-labelledby=#{id}]"

  test "home has no dashboard until a machine has reported" do
    get root_path

    assert_response :success
    assert_select "#stats-heading", false
  end

  test "home charts the machines people reported" do
    3.times { |i| ingest_report!(omarchy_payload, ip: "203.0.113.#{i + 1}") }

    get root_path

    assert_response :success
    assert_select "#stats-heading", "Machines on record"
    assert_select "dl dd", text: "3"
    assert_select "#{chart('stats-vendor')} li", text: /LENOVO.*3/m
    assert_select "#{chart('stats-memory')} li", 6
    assert_select "#{chart('stats-security')} li", text: /UEFI.*100%/m
    assert_select "#{chart('stats-gpu')} li", text: /Intel.*3/m
  end

  test "charts are drawn as text with an aria-hidden SVG and no inline styles" do
    ingest_report!

    get root_path

    assert_select "#{chart('stats-vendor')} li svg[aria-hidden=true] rect", 14
    assert_select "#{chart('stats-vendor')} li svg title", text: "LENOVO: 1"
    assert_select "#main [style]", false
  end

  test "candidates and hidden machines are not charted" do
    ingest_report!(candidate_payload)
    ingest_report!.update!(hidden_at: Time.current)

    get root_path

    assert_select "#stats-heading", false
  end

  test "growth shows as a table behind the columns once there are two weeks" do
    travel_to(2.weeks.ago) { ingest_report! }
    ingest_report!

    get root_path

    assert_select "#stats-growth"
    assert_select "#{chart('stats-growth')} table.sr-only tbody tr", 3
  end
end
