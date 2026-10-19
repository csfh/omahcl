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
    assert_select "section[aria-labelledby=model-security] li", text: /UEFI.*1 of 1/m
    assert_select "section[aria-labelledby=model-security] p", text: "Out of all 1 machine of this model."
  end

  test "show charts only that model, counting its machines out of its total" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "a" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "b" * 64))
    ingest_report!(omarchy_payload(product: "ThinkPad X230", instance_digest: "c" * 64))
    ingest_report!(candidate_payload(product: "ThinkPad X220"))

    get hardware_model_path("lenovo-thinkpad-x220")

    assert_response :success
    assert_select "section[aria-labelledby=model-security] li", text: /UEFI.*2 of 2/m
    assert_select "section[aria-labelledby=model-security] li", text: /Secure Boot on.*0 of 2/m
    assert_select "section[aria-labelledby=model-memory] li", 1
    assert_select "section[aria-labelledby=model-version] li", text: /4\.0\.2.*2/m
    assert_select "#main [style]", false
  end

  test "show leaves out text panels that repeat a chart, and charts architecture" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: "d" * 64))

    get hardware_model_path("lenovo-thinkpad-x220")

    assert_select "dt", text: "Memory seen", count: 0
    assert_select "dt", text: "Omarchy versions", count: 0
    assert_select "dt", text: "CPU models"
    assert_select "dt", text: "GPUs"
    assert_select "#model-version", "Version"
    assert_select "section[aria-labelledby=model-architecture] li", text: /x86_64.*1/m
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
    assert_select "span", text: "Established"
  end

  test "card shows the model with the Omarchy Verified seal for a single machine" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    get card_hardware_model_path("lenovo-thinkpad-x220")

    assert_response :success
    assert_select "[data-controller=holo-card] [data-holo-card-target=card][aria-label^='Omarchy Verified: '][aria-label*='X220']"
    assert_select "h2", /ThinkPad X220/
    assert_select "p", text: "Omarchy Verified"
    assert_select "[style]", count: 0
    assert_no_match(/public_id|instance_digest/, response.body)
  end

  test "model page links to the card" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    get hardware_model_path("lenovo-thinkpad-x220")

    assert_select "a[href=?]", card_hardware_model_path("lenovo-thinkpad-x220")
  end

  test "card is not found for unknown, candidate-only and hidden models" do
    get card_hardware_model_path("lenovo-thinkpad-x220")
    assert_response :not_found

    ingest_report!(candidate_payload(product: "ThinkPad X220"))
    get card_hardware_model_path("lenovo-thinkpad-x220")
    assert_response :not_found

    Report.delete_all
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))
    Report.update_all(hidden_at: Time.current)
    get card_hardware_model_path("lenovo-thinkpad-x220")
    assert_response :not_found
  end
end
