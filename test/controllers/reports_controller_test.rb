require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "create stores a sanitized report" do
    assert_difference -> { Report.count }, 1 do
      post reports_path, params: payload, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["public_id"]
    assert_includes body["claim_url"], "/reports/#{body['public_id']}/claim"
    assert_includes body["model_url"], "/models/lenovo-thinkpad-x220"
  end

  test "create rejects identifier fields" do
    bad = payload.deep_dup
    bad[:hardware][:serial] = "PF123"

    post reports_path, params: bad, as: :json

    assert_response :unprocessable_entity
    assert_equal 0, Report.count
  end

  test "collect serves the python collector" do
    get collect_path

    assert_response :success
    assert_match(/Collect Omarchy hardware facts/, response.body)
    assert_includes response.body, "http://www.example.com"
    refute_includes response.body, "__MARKET_URL__"
  end

  private
    def payload
      {
        omarchy: { version: "4.0.2", channel: "stable" },
        hardware: {
          vendor: "LENOVO",
          product: "ThinkPad X220",
          family: "ThinkPad X220",
          chassis: "Notebook",
          cpu: { model: "Intel Core i5-2520M", vendor: "Intel", arch: "x86_64", cores: 2 },
          memory_bytes: 2_147_483_648,
          gpus: [ { vendor: "Intel", name: "HD Graphics 3000" } ],
          uefi: true,
          tpm: { present: false },
          secure_boot: { enabled: false }
        }
      }
    end
end
