class CreateChallenges < ActiveRecord::Migration[8.1]
  def change
    create_table :challenges do |t|
      t.string :nonce_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.string :issued_ip_digest

      t.timestamps
    end

    add_index :challenges, :nonce_digest, unique: true
  end
end
