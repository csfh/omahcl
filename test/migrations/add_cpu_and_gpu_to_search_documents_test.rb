require "test_helper"
require Rails.root.join("db/migrate/20261023130000_add_cpu_and_gpu_to_search_documents")

class AddCpuAndGpuToSearchDocumentsTest < ActiveSupport::TestCase
  # The migration rebuilds search_document with the CPU and GPU names pages show. It
  # must leave updated_at alone: a card takes its version from the machine that reported last.
  test "the migration rebuilds the search document and leaves updated_at alone" do
    report = ingest_report!(omarchy_payload(cpu: "AMD Ryzen 7 7840U w/ Radeon 780M Graphics"))
    expected = report.search_document
    reported_at = 3.days.ago.change(usec: 0)
    report.update_columns(search_document: "stale", updated_at: reported_at)

    ActiveRecord::Migration.suppress_messages { AddCpuAndGpuToSearchDocuments.new.migrate(:up) }

    stored = Report.find(report.id)
    assert_equal expected, stored.search_document
    assert_includes stored.search_document, "AMD Ryzen 7 7840U"
    assert_includes stored.search_document, "Intel HD Graphics 3000"
    assert_equal reported_at, stored.updated_at
  end

  test "gpus that are not a list of objects are skipped, not fatal" do
    [ nil, {}, "x", [ "x", 1, nil ], [ { "vendor" => "NVIDIA Corporation", "name" => "AD107 [GeForce RTX 4060]" }, "junk" ] ].each do |gpus|
      document = Report.search_document_for("Lenovo", "X1", "ThinkPad X1", cpu_model: "Intel(R) Core(TM) i7-8550U CPU @ 1.80GHz", gpus: gpus)
      assert_includes document, "Intel Core i7-8550U"
    end
    assert_includes Report.search_document_for("Lenovo", "X1", "ThinkPad X1", gpus: [ { "vendor" => "NVIDIA Corporation", "name" => "AD107 [GeForce RTX 4060]" } ]), "GeForce RTX 4060"
  end
end
