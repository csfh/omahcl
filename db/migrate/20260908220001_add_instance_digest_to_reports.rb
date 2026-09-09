class AddInstanceDigestToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :instance_digest, :string, null: false
    add_index :reports, :instance_digest, unique: true
  end
end
