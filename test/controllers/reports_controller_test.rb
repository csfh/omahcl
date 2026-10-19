require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  test "create stores a sanitized report" do
    assert_difference -> { Report.count }, 1 do
      post_report omarchy_payload
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert body["public_id"]
    assert_nil body["claim_url"]
    assert_equal 1, body["known_machines"]
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

  test "collect serves the bash collector" do
    get collect_path

    assert_response :success
    assert_includes response.headers["Content-Disposition"], 'filename="collect.sh"'
    assert_match(/Hardware check for Omarchy/, response.body)
    assert_includes response.body, "#!/usr/bin/env bash"
    assert_includes response.body, "http://www.example.com"
    refute_includes response.body, "__OMAHCL_URL__"
    assert_includes response.body, "/challenges"
    refute_includes response.body, "omarchy-channel-current"
  end

  test "a report learns how many machines of its model have reported" do
    ingest_report!(omarchy_payload(instance_digest: "1" * 64))

    post_report omarchy_payload(instance_digest: "3" * 64)

    body = JSON.parse(response.body)
    assert_equal 2, body["known_machines"]
    assert_includes body["model_url"], "/models/lenovo-thinkpad-x220"
  end

  test "a payload that names a candidate source is rejected" do
    post_report omarchy_payload.merge("source" => "candidate", "verdict" => "likely")

    assert_response :unprocessable_entity
    assert_equal 0, Report.count
  end

  test "an oversized body is refused before it is parsed" do
    padding = "x" * 70.kilobytes
    body = JSON.generate(pad: padding)

    post reports_path, params: body, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :content_too_large
    assert_equal 0, Report.count
  end

  private
    def post_report(payload)
      get challenges_path
      nonce = JSON.parse(response.body)["nonce"]
      post reports_path, params: payload.merge("nonce" => nonce), as: :json
    end
end
