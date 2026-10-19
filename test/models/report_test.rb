require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "ingest stores a report grouped by vendor and product" do
    report = ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    assert report.persisted?
    assert_equal "lenovo|thinkpad x220", report.model_key
    assert_equal "lenovo-thinkpad-x220", report.model_slug
    assert_not_includes Report.column_names, "submitted_ip_digest"
  end

  test "ingested reports are public in model grouping" do
    ingest_report!(omarchy_payload(product: "ThinkPad X220"))

    assert_equal 1, Report.grouped_models.to_a.size
  end

  test "second post with the same instance digest updates instead of inserting" do
    digest = "b" * 64
    report = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: digest))

    again = ingest_report!(omarchy_payload(product: "ThinkPad X220", instance_digest: digest).deep_merge(
      "omarchy" => { "version" => "4.1.0" }
    ))

    assert_equal report.id, again.id
    assert_equal 1, Report.count
    assert_equal "4.1.0", again.reload.omarchy_version
  end

  test "ingest stores a keyed hash of the machine digest, not the one the client sent" do
    digest = "c" * 64
    report = ingest_report!(omarchy_payload(instance_digest: digest))

    assert_equal Report.digest_instance(digest), report.reload.instance_digest
    refute_equal digest, report.instance_digest
    assert_match(/\A[a-f0-9]{64}\z/, report.instance_digest)
  end

  test "reposting one machine does not raise its machine count" do
    digest = "f" * 64
    2.times { ingest_report!(omarchy_payload(instance_digest: digest)) }

    assert_equal 1, Report.grouped_models.first.machines_count
  end

  test "replayed nonce is rejected" do
    payload = omarchy_payload
    nonce, _challenge = Challenge.issue!
    Report.ingest(payload.merge("nonce" => nonce))

    assert_raises(ReportSanitizer::Rejected) do
      Report.ingest(omarchy_payload(instance_digest: "c" * 64).merge("nonce" => nonce))
    end
  end

  test "expired nonce is rejected" do
    payload = omarchy_payload
    nonce, challenge = Challenge.issue!
    challenge.update!(expires_at: 1.minute.ago)

    error = assert_raises(ReportSanitizer::Rejected) do
      Report.ingest(payload.merge("nonce" => nonce))
    end
    assert_match(/challenge/, error.message)
  end

  test "three machines mark a model established, however many networks they use" do
    3.times do |index|
      ingest_report!(omarchy_payload(instance_digest: ::Digest::SHA256.hexdigest("est-#{index}")))
    end

    grouped = Report.grouped_models.first
    assert_equal 3, grouped.machines_count
    assert Report.established?(grouped.machines_count)
  end

  test "two machines are never established" do
    assert_not Report.established?(2)
  end

  test "hidden reports are left out of grouping" do
    report = ingest_report!
    report.update!(hidden_at: Time.current)

    assert_empty Report.grouped_models
    assert report.hidden?
  end

  test "a hidden machine stays hidden when it reports again" do
    digest = "9" * 64
    report = ingest_report!(omarchy_payload(instance_digest: digest))
    report.update!(hidden_at: Time.current)

    ingest_report!(omarchy_payload(instance_digest: digest))

    assert report.reload.hidden?
  end
end
