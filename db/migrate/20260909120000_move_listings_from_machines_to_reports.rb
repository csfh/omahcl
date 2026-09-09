class MoveListingsFromMachinesToReports < ActiveRecord::Migration[8.1]
  def up
    add_reference :listings, :report, foreign_key: true

    execute <<~SQL
      UPDATE listings
      SET report_id = machines.report_id
      FROM machines
      WHERE listings.machine_id = machines.id
    SQL

    change_column_null :listings, :report_id, false
    remove_index :listings, name: "index_listings_on_open_machine"
    remove_reference :listings, :machine, foreign_key: true
    add_index :listings, :report_id, unique: true, where: "status <> 'closed'", name: "index_listings_on_open_report"
    drop_table :machines
  end

  def down
    create_table :machines do |t|
      t.references :user, null: false, foreign_key: true
      t.references :report, null: false, foreign_key: true, index: { unique: true }
      t.timestamps
    end

    add_reference :listings, :machine, foreign_key: true
    execute <<~SQL
      INSERT INTO machines (user_id, report_id, created_at, updated_at)
      SELECT reports.user_id, reports.id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM reports
      WHERE reports.user_id IS NOT NULL
    SQL
    execute <<~SQL
      UPDATE listings
      SET machine_id = machines.id
      FROM machines
      WHERE listings.report_id = machines.report_id
    SQL
    change_column_null :listings, :machine_id, false
    remove_index :listings, name: "index_listings_on_open_report"
    remove_reference :listings, :report, foreign_key: true
    add_index :listings, :machine_id, unique: true, where: "status <> 'closed'", name: "index_listings_on_open_machine"
  end
end
