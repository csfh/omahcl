require "test_helper"

class DeletionsControllerTest < ActionDispatch::IntegrationTest
  DIGEST = "a" * 64

  test "deletes the report of a machine and leaves the others" do
    ingest_report!(omarchy_payload(instance_digest: DIGEST))
    other = ingest_report!(omarchy_payload(instance_digest: "c" * 64))

    post_deletion DIGEST

    assert_response :success
    assert_equal({ "deleted" => 1 }, JSON.parse(response.body))
    assert_equal [ other ], Report.all.to_a
  end

  test "a report an admin hid is deleted too" do
    report = ingest_report!(omarchy_payload(instance_digest: DIGEST))
    report.update!(hidden_at: Time.current)

    post_deletion DIGEST

    assert_equal 1, JSON.parse(response.body)["deleted"]
    assert_equal 0, Report.count
  end

  test "a digest that matches nothing deletes nothing" do
    ingest_report!(omarchy_payload(instance_digest: "c" * 64))

    post_deletion DIGEST

    assert_response :success
    assert_equal 0, JSON.parse(response.body)["deleted"]
    assert_equal 1, Report.count
  end

  test "a stored digest is not a key: only the client digest deletes" do
    report = ingest_report!(omarchy_payload(instance_digest: DIGEST))

    post_deletion report.instance_digest

    assert_equal 0, JSON.parse(response.body)["deleted"]
    assert_equal 1, Report.count
  end

  test "a reused nonce is rejected" do
    ingest_report!(omarchy_payload(instance_digest: DIGEST))
    get challenges_path
    nonce = JSON.parse(response.body)["nonce"]
    post deletions_path, params: { instance_digest: "d" * 64, nonce: nonce }, as: :json
    assert_response :success

    post deletions_path, params: { instance_digest: DIGEST, nonce: nonce }, as: :json

    assert_response :unprocessable_entity
    assert_equal 1, Report.count
  end

  test "an expired nonce is rejected" do
    ingest_report!(omarchy_payload(instance_digest: DIGEST))
    nonce, challenge = Challenge.issue!
    challenge.update!(expires_at: 1.minute.ago)

    post deletions_path, params: { instance_digest: DIGEST, nonce: nonce }, as: :json

    assert_response :unprocessable_entity
    assert_equal 1, Report.count
  end

  test "a missing nonce, a bad digest and extra keys are rejected" do
    ingest_report!(omarchy_payload(instance_digest: DIGEST))
    nonce, _challenge = Challenge.issue!

    [
      { instance_digest: DIGEST },
      { instance_digest: "not-a-digest", nonce: nonce },
      { instance_digest: [ DIGEST ], nonce: nonce },
      { instance_digests: [ DIGEST ], nonce: nonce },
      { instance_digest: DIGEST, nonce: nonce, hostname: "laptop" }
    ].each do |params|
      post deletions_path, params: params, as: :json
      assert_response :unprocessable_entity, params.inspect
    end
    assert_equal 1, Report.count
  end

  test "invalid JSON is a bad request" do
    post deletions_path, params: "{", headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :bad_request
  end

  test "an oversized body is refused before it is parsed" do
    post deletions_path, params: { instance_digest: DIGEST, nonce: "x" * 70_000 }, as: :json

    assert_response :content_too_large
  end

  private
    def post_deletion(digest)
      get challenges_path
      nonce = JSON.parse(response.body)["nonce"]
      post deletions_path, params: { instance_digest: digest, nonce: nonce }, as: :json
    end
end
