require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "create stores a sanitized report" do
    assert_difference -> { Report.count }, 1 do
      post_report omarchy_payload
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["public_id"]
    assert_includes body["claim_url"], "/reports/#{body['public_id']}/claim"
    assert_includes body["model_url"], "/models/lenovo-thinkpad-x220"
  end

  test "create rejects identifier fields" do
    bad = omarchy_payload
    bad["hardware"]["serial"] = "PF123"

    post_report bad

    assert_response :unprocessable_entity
    assert_equal 0, Report.count
  end

  test "create rejects a reused nonce" do
    get challenges_path
    nonce = JSON.parse(response.body)["nonce"]
    post reports_path, params: omarchy_payload.merge("nonce" => nonce), as: :json
    assert_response :created

    post reports_path, params: omarchy_payload(instance_digest: "e" * 64).merge("nonce" => nonce), as: :json
    assert_response :unprocessable_entity
  end

  test "collect serves the python collector" do
    get collect_path

    assert_response :success
    assert_match(/Collect Omarchy hardware facts/, response.body)
    assert_includes response.body, "http://www.example.com"
    refute_includes response.body, "__MARKET_URL__"
    assert_includes response.body, "/challenges"
    refute_includes response.body, "omarchy-channel-current"
  end

  private
    def post_report(payload)
      get challenges_path
      nonce = JSON.parse(response.body)["nonce"]
      post reports_path, params: payload.merge("nonce" => nonce), as: :json
    end
end
