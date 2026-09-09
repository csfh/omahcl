require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "ingest stores a claimable report grouped by vendor and product" do
    report, token = ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    assert report.persisted?
    assert_equal "lenovo|thinkpad x220", report.model_key
    assert_equal "lenovo-thinkpad-x220", report.model_slug
    assert report.claimable?(token)
    refute_equal token, report.claim_token_digest
    assert_not_nil report.submitted_ip_digest
  end

  test "unclaimed reports are omitted from public grouping" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    assert_empty Report.grouped_models
  end

  test "second post with the same instance digest updates instead of inserting" do
    digest = "b" * 64
    report, _token = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: digest))

    again, token = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: digest).deep_merge(
      "omarchy" => { "version" => "4.1.0" }
    ))

    assert_equal report.id, again.id
    assert_equal 1, Report.count
    assert_equal "4.1.0", again.reload.omarchy_version
    assert again.claimable?(token)
  end

  test "replayed nonce is rejected" do
    payload = omarchy_payload
    nonce, _challenge = Challenge.issue!(ip: "203.0.113.10")
    Report.ingest(payload.merge("nonce" => nonce), ip: "203.0.113.10")

    assert_raises(ReportSanitizer::Rejected) do
      Report.ingest(omarchy_payload(instance_digest: "c" * 64).merge("nonce" => nonce), ip: "203.0.113.10")
    end
  end

  test "expired nonce is rejected" do
    payload = omarchy_payload
    nonce, challenge = Challenge.issue!(ip: "203.0.113.10")
    challenge.update!(expires_at: 1.minute.ago)

    error = assert_raises(ReportSanitizer::Rejected) do
      Report.ingest(payload.merge("nonce" => nonce), ip: "203.0.113.10")
    end
    assert_match(/challenge/, error.message)
  end

  test "claim attaches the report to the user" do
    report, token = ingest_report!
    user = users(:one)

    report.claim!(user: user, token: token)

    assert_equal user, report.reload.user
    assert report.claimed?
    refute report.claimable?(token)
    assert_equal 1, Report.grouped_models.to_a.size
  end

  test "two users cannot claim the same digest" do
    report, token = ingest_report!
    report.claim!(user: users(:one), token: token)

    refute report.claimable?(token)
  end

  test "a user cannot claim more than five reports" do
    user = users(:one)
    5.times do |index|
      report, token = ingest_report!(omarchy_payload(instance_digest: ::Digest::SHA256.hexdigest("cap-#{index}")))
      report.claim!(user: user, token: token)
    end

    report, token = ingest_report!(omarchy_payload(instance_digest: "d" * 64))
    error = assert_raises(Report::ClaimRejected) do
      report.claim!(user: user, token: token)
    end
    assert_match(/at most 5 reports/, error.message)
  end

  test "three independent claimants mark a model established" do
    [ users(:one), users(:two), users(:admin) ].each_with_index do |user, index|
      report, token = ingest_report!(omarchy_payload(instance_digest: ::Digest::SHA256.hexdigest("est-#{index}")))
      report.claim!(user: user, token: token)
    end

    grouped = Report.grouped_models.first
    assert_equal 3, grouped.claimants_count
    assert Report.established?(grouped.claimants_count)
  end

  test "expired or wrong tokens are not claimable" do
    report, token = ingest_report!

    refute report.claimable?("nope")
    report.update!(claim_token_expires_at: 1.minute.ago)
    refute report.claimable?(token)
  end
end
