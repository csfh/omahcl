class AddCpuAndGpuToSearchDocuments < ActiveRecord::Migration[8.1]
  # Search also matches the CPU and GPU names pages show. Rebuilds every report's
  # search_document through Report.search_document_for, which is meant to follow
  # Report::Display. It uses update, not the model, so updated_at stays as it is: the
  # card takes its version from the machine that reported last.
  def up
    rows = connection.select_rows("SELECT id, vendor, product, family, cpu_model, gpus FROM reports")
    rows.each do |id, vendor, product, family, cpu_model, gpus|
      gpus = JSON.parse(gpus) if gpus.is_a?(String)
      document = Report.search_document_for(vendor, product, family, cpu_model: cpu_model, gpus: gpus)
      connection.exec_update("UPDATE reports SET search_document = $1 WHERE id = $2", "AddCpuAndGpuToSearchDocuments", [ document, id ])
    end
    say "Rebuilt #{rows.size} search documents"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
