class AddHiddenAtToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :hidden_at, :datetime
  end
end
