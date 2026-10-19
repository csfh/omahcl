require "test_helper"
require Rails.root.join("db/migrate/20261019120000_add_card_key_to_reports")

class AddCardKeyToReportsTest < ActiveSupport::TestCase
  # The migration spells the formula out. This keeps it from drifting from the model.
  test "the formula in the migration matches Report.card_key_for" do
    report = ingest_report!(omarchy_payload(cpu: "  AMD  Ryzen 7 7840U "))
    expected = report.card_key

    ActiveRecord::Migration.suppress_messages do
      migration = AddCardKeyToReports.new
      migration.connection.execute("UPDATE reports SET card_key = 'stale'")
      migration.connection.remove_index :reports, :card_key
      migration.connection.remove_column :reports, :card_key
      migration.migrate(:up)
    end

    assert_equal expected, Report.find(report.id).card_key
    assert_equal Report.card_key_for(report.model_key, "amd ryzen 7 7840u"), expected
  end
end
