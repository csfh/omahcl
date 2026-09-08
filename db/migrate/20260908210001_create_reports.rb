class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.uuid :public_id, null: false
      t.references :user, foreign_key: true
      t.string :omarchy_version, null: false
      t.string :omarchy_channel, null: false, default: "stable"
      t.string :vendor, null: false
      t.string :product, null: false
      t.string :family
      t.string :chassis
      t.string :cpu_model, null: false
      t.string :cpu_vendor
      t.string :cpu_arch, null: false
      t.integer :cpu_cores, null: false, default: 0
      t.bigint :memory_bytes, null: false, default: 0
      t.jsonb :gpus, null: false, default: []
      t.boolean :uefi, null: false, default: false
      t.boolean :tpm_present, null: false, default: false
      t.boolean :secure_boot_enabled, null: false, default: false
      t.jsonb :facts, null: false, default: {}
      t.string :model_key, null: false
      t.string :model_slug, null: false
      t.string :search_document, null: false, default: ""
      t.string :claim_token_digest
      t.datetime :claim_token_expires_at
      t.datetime :claimed_at
      t.string :submitted_ip_digest

      t.timestamps
    end

    add_index :reports, :public_id, unique: true
    add_index :reports, :model_key
    add_index :reports, :model_slug
    add_index :reports, :search_document, using: :gin, opclass: :gin_trgm_ops
    add_index :reports, :claim_token_digest, unique: true, where: "claim_token_digest IS NOT NULL"
  end
end
