require "test_helper"

# Production logs at info, so capture at that level: what shows up here is what
# production would keep.
class RequestLoggingTest < ActionDispatch::IntegrationTest
  CLIENT_IP = "203.0.113.7"

  setup do
    @log = StringIO.new
    @capture = ActiveSupport::Logger.new(@log, level: :info)
    Rails.logger.broadcast_to(@capture)
  end

  teardown do
    Rails.logger.stop_broadcasting_to(@capture)
  end

  test "request logs leave out the client IP" do
    get hardware_models_path, headers: { "REMOTE_ADDR" => CLIENT_IP }

    assert_match %r{Started GET "/models"}, @log.string
    assert_no_match CLIENT_IP, @log.string
  end

  test "report logs leave out the machine digest and nonce" do
    get challenges_path, headers: { "REMOTE_ADDR" => CLIENT_IP }
    nonce = JSON.parse(response.body)["nonce"]
    digest = "d" * 64

    post reports_path, params: omarchy_payload(instance_digest: digest).merge("nonce" => nonce), as: :json, headers: { "REMOTE_ADDR" => CLIENT_IP }

    assert_response :created
    assert_match "Parameters:", @log.string
    assert_no_match digest, @log.string
    assert_no_match nonce, @log.string
    assert_no_match CLIENT_IP, @log.string
  end

  test "deletion logs leave out the machine digests and nonce" do
    get challenges_path, headers: { "REMOTE_ADDR" => CLIENT_IP }
    nonce = JSON.parse(response.body)["nonce"]
    digest = "e" * 64

    post deletions_path, params: { instance_digests: [ digest ], nonce: nonce }, as: :json, headers: { "REMOTE_ADDR" => CLIENT_IP }

    assert_response :success
    assert_match "Parameters:", @log.string
    assert_no_match digest, @log.string
    assert_no_match nonce, @log.string
    assert_no_match CLIENT_IP, @log.string
  end

  # Action Cable writes its own "Started … for <ip>" line, outside AnonymousRequestLogger.
  test "the unused Action Cable endpoint is not served and logs no IP" do
    get "/cable", headers: { "REMOTE_ADDR" => CLIENT_IP }

    assert_response :not_found
    assert_no_match CLIENT_IP, @log.string
  end

  test "search logs leave out the query" do
    get hardware_models_path(q: "x220-search-term")
    get suggestions_hardware_models_path(q: "x220-search-term")

    assert_match "Parameters:", @log.string
    assert_no_match "x220-search-term", @log.string
  end
end
