class CreateListings < ActiveRecord::Migration[8.1]
  def change
    create_table :listings do |t|
      t.references :machine, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :condition
      t.string :status, null: false, default: "published"
      t.string :title, null: false
      t.text :description
      t.integer :price_cents
      t.string :currency
      t.string :city
      t.string :country_code
      t.references :donation_destination, foreign_key: true

      t.timestamps
    end

    add_index :listings, :machine_id, unique: true, where: "status <> 'closed'", name: "index_listings_on_open_machine"
    add_index :listings, :status
    add_index :listings, :kind
  end
end
