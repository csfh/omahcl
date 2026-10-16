require "test_helper"

class HardwareModelsControllerTest < ActionDispatch::IntegrationTest
  test "home is public" do
    get root_path
    assert_response :success
    assert_select "h1", /Omarchy/
    assert_select "h2", "Report your machine"
    assert_select "[data-controller=clipboard]"
    assert_select "[data-clipboard-target=source]", text: /curl -fsSL .+\/collect \| bash/
    assert_select "button[type=button][data-action='clipboard#copy']", text: "Copy"
    assert_select "nav a", text: "Classifieds", count: 0
    assert_select "nav a", text: "Sign up", count: 0
  end

  test "home lists machines people have run" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    get root_path

    assert_response :success
    assert_select "h2", "Machines people run"
    assert_select "a", text: /ThinkPad X220/
    assert_select "nav a", text: "Machines"
  end

  test "reports appear in lookup right away" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    get hardware_models_path, params: { q: "X220" }
    assert_response :success
    assert_select "a", text: /ThinkPad X220/

    get hardware_model_path("lenovo-thinkpad-x220")
    assert_response :success
  end

  test "unknown model is not found" do
    get hardware_model_path("lenovo-thinkpad-x220")
    assert_response :not_found
  end

  test "index filters models by query" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "1" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "2" * 64))

    get hardware_models_path, params: { q: "X220" }

    assert_response :success
    assert_select "h1", "Machines that run Omarchy"
    assert_select "a", text: /ThinkPad X220/
    assert_select "a", text: /ThinkPad X230/, count: 0
    assert_select "span", /Only a few machines so far/
  end

  test "suggestions return matching models as typeahead html" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "4" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "5" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "6" * 64))

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

  test "show counts distinct machines for a slug" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "3" * 64))

    get hardware_model_path("lenovo-thinkpad-x220")

    assert_response :success
    assert_select "h1", /ThinkPad X220/
    assert_match(/1 machine reported running Omarchy/, response.body)
    assert_match(/Only a few machines so far/, response.body)
  end

  test "hidden reports are not public" do
    report = ingest_report!(omarchy_payload(product: "ThinkPad X220"))
    report.update!(hidden_at: Time.current)

    get hardware_models_path, params: { q: "X220" }
    assert_select "a", text: /ThinkPad X220/, count: 0

    get hardware_model_path("lenovo-thinkpad-x220")
    assert_response :not_found
  end

  test "show says established only with machines on several networks" do
    3.times do |index|
      ingest_report!(omarchy_payload(instance_digest: ::Digest::SHA256.hexdigest("show-#{index}")), ip: "203.0.113.#{index + 20}")
    end

    get hardware_model_path("lenovo-thinkpad-x220")

    assert_match(/3 machines reported running Omarchy/, response.body)
    assert_select "span", text: "Verified"
  end
end
