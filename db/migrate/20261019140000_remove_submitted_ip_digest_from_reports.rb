class RemoveSubmittedIpDigestFromReports < ActiveRecord::Migration[8.1]
  def up
    remove_column :reports, :submitted_ip_digest
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
