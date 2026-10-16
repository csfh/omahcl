class AddCandidateReports < ActiveRecord::Migration[8.1]
  def change
    # omarchy: sent by a machine running Omarchy. candidate: sent from another
    # OS after the person opted in; never counted on public pages.
    add_column :reports, :source, :string, null: false, default: "omarchy"
    add_column :reports, :verdict, :string
    add_column :reports, :host_os, :string
    add_check_constraint :reports, "source IN ('omarchy', 'candidate')", name: "reports_source_check"
    change_column_null :reports, :omarchy_version, true
  end
end
