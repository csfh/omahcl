require "test_helper"

class HardwareModelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Report.ingest(payload("ThinkPad X220"), ip: "203.0.113.1")
    Report.ingest(payload("ThinkPad X230"), ip: "203.0.113.2")
  end

  test "home is public" do
    get root_path
    assert_response :success
    assert_select "h1", /Omarchy/
  end

  test "index filters by query" do
    get hardware_models_path, params: { q: "X220" }

    assert_response :success
    assert_select "a", text: /ThinkPad X220/
    assert_select "a", text: /ThinkPad X230/, count: 0
  end

  test "show groups installs for a slug" do
    get hardware_model_path("lenovo-thinkpad-x220")

    assert_response :success
    assert_select "h1", /ThinkPad X220/
    assert_match(/1 verified/, response.body)
  end

  private
    def payload(product)
      {
        "omarchy" => { "version" => "4.0.2", "channel" => "stable" },
        "hardware" => {
          "vendor" => "LENOVO",
          "product" => product,
          "cpu" => { "model" => "Intel Core i5-2520M", "arch" => "x86_64", "cores" => 2 },
          "memory_bytes" => 2_147_483_648,
          "gpus" => [],
          "uefi" => true
        }
      }
    end
end
