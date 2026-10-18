class HashInstanceDigests < ActiveRecord::Migration[8.1]
  # Keys every stored machine digest the way Report.digest_instance keys new ones,
  # so machines that report again still match their own report. It calls the
  # connection directly so the deploy log prints a count, not each digest.
  def up
    key = Rails.application.key_generator.generate_key("report instance digest")
    rows = connection.select_rows("SELECT id, instance_digest FROM reports")

    rows.each do |id, digest|
      connection.exec_update(
        "UPDATE reports SET instance_digest = $1 WHERE id = $2",
        "HashInstanceDigests",
        [ OpenSSL::HMAC.hexdigest("SHA256", key, digest), id ]
      )
    end
    say "Keyed #{rows.size} machine digests"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
