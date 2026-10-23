require "test_helper"
require Rails.root.join("db/migrate/20261022200000_normalize_report_vendors")

class NormalizeReportVendorsTest < ActiveSupport::TestCase
  # The migration spells the key, slug and card formulas out. This keeps it from
  # drifting from the model, and shows it leaves the machine's digest alone.
  test "the migration rewrites stored identity exactly as the model builds it" do
    report = ingest_report!(omarchy_payload(product: "XPS 13", cpu: "Intel Core i7").deep_merge("hardware" => { "vendor" => "Dell  Inc." }))
    # search_document is left out: the model now builds it with the CPU and GPU names
    # (see AddCpuAndGpuToSearchDocuments), and this migration writes what it did then.
    expected = report.attributes.slice("vendor", "product", "model_key", "model_slug", "card_key")
    digest = report.instance_digest
    Report.where(id: report.id).update_all(
      vendor: "Dell  Inc.", product: "XPS  13", model_key: "dell  inc.|xps  13", model_slug: "old",
      card_key: "stale"
    )

    ActiveRecord::Migration.suppress_messages { NormalizeReportVendors.new.migrate(:up) }

    stored = Report.find(report.id)
    assert_equal expected, stored.attributes.slice(*expected.keys)
    assert_equal "Dell", stored.vendor
    assert_equal Report.card_key_for("dell|xps 13", "Intel Core i7"), stored.card_key
    assert_equal digest, stored.instance_digest
  end
end
