class RemoveCandidateReports < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM reports WHERE source = 'candidate'"
    remove_check_constraint :reports, name: "reports_source_check"
    remove_column :reports, :source
    remove_column :reports, :verdict
    remove_column :reports, :host_os
    change_column_null :reports, :omarchy_version, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
