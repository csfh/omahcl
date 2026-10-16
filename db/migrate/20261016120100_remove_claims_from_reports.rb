class RemoveClaimsFromReports < ActiveRecord::Migration[8.1]
  def up
    # Reports nobody claimed were promised to stay private. The product no longer
    # has claims, so they are deleted rather than published.
    execute "DELETE FROM reports WHERE user_id IS NULL"

    remove_index :reports, :claim_token_digest
    remove_reference :reports, :user, foreign_key: true, index: true
    remove_column :reports, :claim_token_digest
    remove_column :reports, :claim_token_expires_at
    remove_column :reports, :claimed_at
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
