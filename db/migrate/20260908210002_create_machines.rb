class CreateMachines < ActiveRecord::Migration[8.1]
  def change
    create_table :machines do |t|
      t.references :user, null: false, foreign_key: true
      t.references :report, null: false, foreign_key: true, index: { unique: true }

      t.timestamps
    end
  end
end
