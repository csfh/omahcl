class AddCardKeyToReports < ActiveRecord::Migration[8.1]
  # A card key names one configuration, a model with one CPU, so two Framework
  # Laptop 13 machines with different CPUs get different cards. The formula is
  # written out here, not taken from Report.card_key_for, because a migration
  # must keep producing the same keys after the model changes.
  def up
    add_column :reports, :card_key, :string
    add_index :reports, :card_key

    rows = connection.select_rows("SELECT id, model_key, cpu_model FROM reports")
    rows.each do |id, model_key, cpu_model|
      cpu = cpu_model.to_s.strip.gsub(/\s+/, " ").downcase
      key = Digest::SHA256.hexdigest("omahcl-card-v1|#{model_key}|#{cpu}")[0, 16]
      connection.exec_update("UPDATE reports SET card_key = $1 WHERE id = $2", "AddCardKeyToReports", [ key, id ])
    end
    say "Keyed #{rows.size} reports"

    change_column_null :reports, :card_key, false
  end

  def down
    remove_index :reports, :card_key
    remove_column :reports, :card_key
  end
end
