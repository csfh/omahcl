class RemoveIpDataFromChallengesAndSessions < ActiveRecord::Migration[8.1]
  def up
    remove_column :challenges, :issued_ip_digest
    remove_column :sessions, :ip_address
    remove_column :sessions, :user_agent
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
