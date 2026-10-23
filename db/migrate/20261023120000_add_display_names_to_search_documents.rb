class AddDisplayNamesToSearchDocuments < ActiveRecord::Migration[8.1]
  # Search matches the name pages show as well as what the firmware said, so a
  # machine is found by "Vivobook X510" and not only by "X510UQR". Rebuilds every
  # report's search_document through Report.search_document_for, which is meant to
  # follow Report::Display. It uses update, not the model, so updated_at stays as it
  # is: the card takes its version from the machine that reported last.
  def up
    rows = connection.select_rows("SELECT id, vendor, product, family FROM reports")
    rows.each do |id, vendor, product, family|
      document = Report.search_document_for(vendor, product, family)
      connection.exec_update("UPDATE reports SET search_document = $1 WHERE id = $2", "AddDisplayNamesToSearchDocuments", [ document, id ])
    end
    say "Rebuilt #{rows.size} search documents"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
