class CreateDonationDestinations < ActiveRecord::Migration[8.1]
  def change
    create_table :donation_destinations do |t|
      t.string :name, null: false
      t.string :url, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
