require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_root_path
    assert_redirected_to root_path
  end

  test "admin sees counts" do
    report, token = ingest_report!
    report.claim!(user: users(:one), token: token)
    Listing.create!(
      report: report,
      kind: "sale",
      title: "Used X220",
      condition: "used",
      price_amount: "150",
      currency: "USD",
      city: "Copenhagen",
      country_code: "DK",
      status: "published"
    )
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "a" * 64))

    sign_in_as(users(:admin))
    get admin_root_path

    assert_response :success
    assert_select "h1", "Admin"
    assert_select "h2", "Collections submitted"
    assert_select "a", text: "2 collections"
    assert_select "dd", text: "2"
    assert_select "dd", text: "2 types"
    assert_select "a", text: "1 claimed"
    assert_select "a", text: "1 unclaimed"
    assert_select "a", text: /ThinkPad X220/
    assert_select "a", text: /ThinkPad X230/
    assert_select "a", text: "3 accounts"
    assert_select "a", text: "1 published"
    assert_select "a", text: "0 open"
    assert_select "a", text: "2 consumed"
    assert_select "nav[aria-label=Admin] a", text: "Home"
    assert_select "nav[aria-label=Admin] a", text: "Challenges"
  end
end
