class NormalizeReportVendors < ActiveRecord::Migration[8.1]
  # Rewrites every report's vendor to its canonical name and rebuilds what is built
  # from it: model_key, model_slug, card_key and search_document. Machines keep their
  # instance_digest, which the client hashed from the raw strings. Old /hardware and
  # /cards links for a renamed vendor stop working by the owner's choice; no legacy
  # table or redirects.
  #
  # The key, slug and card formulas are written out, as in AddCardKeyToReports, so
  # they keep producing these values after the model changes. The vendor spelling
  # comes from Report::Vendor, the one place that decides it.
  def up
    rows = connection.select_rows("SELECT id, vendor, product, family, cpu_model FROM reports")
    rows.each do |id, raw_vendor, raw_product, family, cpu_model|
      vendor = Report::Vendor.canonical(raw_vendor)
      product = raw_product.to_s.strip.gsub(/\s+/, " ")
      model_key = [ vendor.downcase, product.downcase ].join("|")
      model_slug = [ vendor, product ].join(" ").parameterize
      cpu = cpu_model.to_s.strip.gsub(/\s+/, " ").downcase
      card_key = Digest::SHA256.hexdigest("omahcl-card-v1|#{model_key}|#{cpu}")[0, 16]
      search_document = [ vendor, product, family ].compact.join(" ")

      connection.exec_update(<<~SQL, "NormalizeReportVendors", [ vendor, product, model_key, model_slug, card_key, search_document, id ])
        UPDATE reports
        SET vendor = $1, product = $2, model_key = $3, model_slug = $4, card_key = $5, search_document = $6
        WHERE id = $7
      SQL
    end
    say "Normalized #{rows.size} reports"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
