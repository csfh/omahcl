class DeleteNonAdminUsers < ActiveRecord::Migration[8.1]
  # Accounts only exist for admins now. Everyone else lost their reason to have
  # one when claims, listings, and sign-up were removed.
  def up
    execute "DELETE FROM sessions WHERE user_id IN (SELECT id FROM users WHERE NOT admin)"
    execute "DELETE FROM users WHERE NOT admin"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
