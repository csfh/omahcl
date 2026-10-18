require "test_helper"
require Rails.root.join("db/migrate/20261017120000_hash_instance_digests")

class HashInstanceDigestsTest < ActiveSupport::TestCase
  test "a machine that reports again after the migration updates its own report" do
    digest = "9" * 64
    report = ingest_report!(omarchy_payload(instance_digest: digest))
    report.update_column(:instance_digest, digest)

    ActiveRecord::Migration.suppress_messages { HashInstanceDigests.new.migrate(:up) }
    again = ingest_report!(omarchy_payload(instance_digest: digest))

    assert_equal report.id, again.id
    assert_equal 1, Report.count
  end
end
