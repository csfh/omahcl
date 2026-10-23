require "test_helper"
require Rails.root.join("db/migrate/20261023120000_add_display_names_to_search_documents")

class AddDisplayNamesToSearchDocumentsTest < ActiveSupport::TestCase
  # The migration rebuilds search_document with the name pages show. It must leave
  # updated_at alone: a card takes its version from the machine that reported last.
  test "the migration rebuilds the search document and leaves updated_at alone" do
    report = ingest_report!(omarchy_payload(product: "X510UQR").deep_merge("hardware" => { "vendor" => "ASUSTeK COMPUTER INC.", "family" => "VivoBook" }))
    reported_at = 3.days.ago.change(usec: 0)
    report.update_columns(search_document: "stale", updated_at: reported_at)

    ActiveRecord::Migration.suppress_messages { AddDisplayNamesToSearchDocuments.new.migrate(:up) }

    stored = Report.find(report.id)
    assert_equal Report.search_document_for("ASUS", "X510UQR", "VivoBook"), stored.search_document
    assert_includes stored.search_document, "ASUS Vivobook X510UQR"
    assert_equal reported_at, stored.updated_at
  end
end
