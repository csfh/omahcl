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
    assert_match(/Hardware check for Omarchy/, response.body)
    assert_includes response.body, "#!/usr/bin/env bash"
    assert_includes response.body, "http://www.example.com"
    refute_includes response.body, "__MARKET_URL__"
    assert_includes response.body, "/challenges"
    refute_includes response.body, "omarchy-channel-current"
  end

  test "a candidate is stored but never counted publicly" do
    assert_difference -> { Report.source_candidate.count }, 1 do
      post_report candidate_payload
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal 0, body["known_machines"]
    assert_nil body["model_url"]
    assert_empty Report.grouped_models
    get hardware_models_path, params: { q: "X220" }
    assert_select "a", text: /ThinkPad X220/, count: 0
  end

  test "a candidate learns how many machines of its model run omarchy" do
    ingest_report!(omarchy_payload(instance_digest: "1" * 64))
    ingest_report!(omarchy_payload(instance_digest: "2" * 64))

    post_report candidate_payload(instance_digest: "3" * 64)

    body = JSON.parse(response.body)
    assert_equal 2, body["known_machines"]
    assert_includes body["model_url"], "/models/lenovo-thinkpad-x220"
    assert_equal 2, Report.grouped_models.first.machines_count
  end

  test "a candidate cannot overwrite a machine that reported from omarchy" do
    digest = "4" * 64
    report = ingest_report!(omarchy_payload(instance_digest: digest))

    post_report candidate_payload(instance_digest: digest, verdict: "unlikely")

    assert_response :ok
    assert report.reload.source_omarchy?
    assert_nil report.verdict
  end

  test "a candidate that later runs omarchy becomes a public report" do
    digest = "5" * 64
    ingest_report!(candidate_payload(instance_digest: digest))

    post_report omarchy_payload(instance_digest: digest)

    report = Report.find_by!(instance_digest: digest)
    assert report.source_omarchy?
    assert_nil report.verdict
    assert_equal 1, Report.grouped_models.first.machines_count
  end

  test "create rejects a candidate that claims omarchy details" do
    post_report candidate_payload.merge("omarchy" => { "version" => "4.0.2" })

    assert_response :unprocessable_entity
    assert_equal 0, Report.count
  end

  test "an oversized body is refused before it is parsed" do
    padding = "x" * 70.kilobytes
    body = JSON.generate(source: "candidate", verdict: "likely", pad: padding)

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
