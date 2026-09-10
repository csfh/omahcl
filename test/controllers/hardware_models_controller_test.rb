require "test_helper"

class HardwareModelsControllerTest < ActionDispatch::IntegrationTest
  test "home is public" do
    get root_path
    assert_response :success
    assert_select "h1", /Omarchy/
    assert_select "h2", "Add your machine"
    assert_select "ol li", minimum: 4
    assert_select "[data-controller=clipboard]"
    assert_select "[data-clipboard-target=source]", text: /curl -fsSL .+\/collect \| bash/
    assert_select "button[type=button][data-action='clipboard#copy']", text: "Copy"
  end

  test "home lists machines people have run" do
    report, token = ingest_report!(omarchy_payload(product: "ThinkPad X220"))
    report.claim!(user: users(:one), token: token)

    get root_path

    assert_response :success
    assert_select "h2", "Machines people run"
    assert_select "a", text: /ThinkPad X220/
    assert_select "h2", "Add your machine"
    assert_select "nav a", text: "Machines"
    assert_select "nav a", text: "Classifieds"
  end

  test "unclaimed reports do not appear in lookup" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    get hardware_models_path, params: { q: "X220" }
    assert_response :success
    assert_select "a", text: /ThinkPad X220/, count: 0

    get hardware_model_path("lenovo-thinkpad-x220")
    assert_response :not_found
  end

  test "index filters claimed models by query" do
    x220, x220_token = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "1" * 64))
    x230, x230_token = ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "2" * 64))
    x220.claim!(user: users(:one), token: x220_token)
    x230.claim!(user: users(:two), token: x230_token)

    get hardware_models_path, params: { q: "X220" }

    assert_response :success
    assert_select "h1", "Machines that run Omarchy"
    assert_select "a", text: /ThinkPad X220/
    assert_select "a", text: /ThinkPad X230/, count: 0
    assert_select "span", /Only a few people so far/
  end

  test "suggestions return claimed models as typeahead html" do
    x220, x220_token = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "4" * 64))
    x230, x230_token = ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "5" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "6" * 64))
    x220.claim!(user: users(:one), token: x220_token)
    x230.claim!(user: users(:two), token: x230_token)

    get suggestions_hardware_models_path, params: { q: "X220" }

    assert_response :success
    assert_select "li[role=option]", count: 1
    assert_select "a", text: /ThinkPad X220/
    assert_select "a", text: /ThinkPad X230/, count: 0
  end

  test "suggestions are empty without a query" do
    get suggestions_hardware_models_path, params: { q: "" }

    assert_response :success
    assert_select "li[role=option]", count: 0
  end

  test "show groups claimed people for a slug" do
    report, token = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "3" * 64))
    report.claim!(user: users(:one), token: token)

    get hardware_model_path("lenovo-thinkpad-x220")

    assert_response :success
    assert_select "h1", /ThinkPad X220/
    assert_match(/1 person has run Omarchy on this machine/, response.body)
    assert_match(/Only a few people so far/, response.body)
  end
end
