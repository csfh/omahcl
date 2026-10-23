require "test_helper"

class ErrorsTest < ActionDispatch::IntegrationTest
  # The test environment shows Rails' debug page; production runs exceptions_app.
  setup { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false }
  teardown { Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = true }

  test "an unknown address gets the branded 404 with a way forward" do
    get "/no-such-page"

    assert_response :not_found
    assert_select "h1", text: "Page not found"
    assert_select "form[action=?]", hardware_models_path
    assert_select "a[href=?]", root_path, text: "Home"
    assert_select "meta[name=robots][content=noindex]"
    assert_select "link[rel=canonical]", count: 0
    assert_select "[data-clipboard-target=source]", text: /curl -fsSL .+\/collect \| bash/
    assert_select "p", text: /first report creates its page and its card/
  end

  test "a missing model and a missing card get it too" do
    get "/models/no-such-model"
    assert_response :not_found
    assert_select "h1", text: "Page not found"

    get card_path("0" * 16)
    assert_response :not_found
    assert_select "h1", text: "Page not found"
  end

  test "a card image or JSON request for something missing is a plain 404, not a 500" do
    get card_path("0" * 16, format: :png)
    assert_response :not_found

    get "/models/no-such-model.json"
    assert_response :not_found

    get "/no-such-page", headers: { "Accept" => "application/json" }
    assert_response :not_found
  end

  test "an old vendor address offers a search that finds the model's new page" do
    ingest_report!(omarchy_payload(product: "XPS 14 DA14260").deep_merge("hardware" => { "vendor" => "Dell Inc." }))

    get "/models/dell-inc-xps-14-da14260"

    assert_response :not_found
    assert_select "input[name=q][value=?]", "Dell xps 14 da14260"
    get hardware_models_path(q: "Dell xps 14 da14260")
    assert_select "a[href=?]", hardware_model_path("dell-xps-14-da14260")
  end

  test "other errors keep their static page" do
    assert_includes File.read(Rails.public_path.join("500.html")), "500"
    app = Rails.application.config.exceptions_app
    status, _headers, _body = app.call("PATH_INFO" => "/500", "HTTP_ACCEPT" => "text/html", "REQUEST_METHOD" => "GET")

    assert_equal 500, status
  end
end
