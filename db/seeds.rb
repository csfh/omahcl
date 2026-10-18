if Rails.env.development?
  def ensure_report(vendor:, product:, key:, cpu_model:, memory_bytes:, cpu_cores: 2)
    digest = Report.digest_instance(Digest::SHA256.hexdigest("market-seed:#{key}"))
    report = Report.find_or_initialize_by(instance_digest: digest)
    report.assign_attributes(
      omarchy_version: "4.0.2",
      omarchy_channel: "stable",
      vendor: vendor,
      product: product,
      cpu_model: cpu_model,
      cpu_vendor: "Intel",
      cpu_arch: "x86_64",
      cpu_cores: cpu_cores,
      memory_bytes: memory_bytes,
      gpus: [ { "vendor" => "Intel", "name" => "HD Graphics 3000" } ],
      uefi: true,
      facts: {}
    )
    report.save!
    report
  end

  password = "password"
  admin = User.find_or_initialize_by(email_address: "admin@example.com")
  admin.assign_attributes(password: password, password_confirmation: password, admin: true)
  admin.save!

  [
    [ "LENOVO", "ThinkPad X220", "x220-a", "Intel Core i5-2520M", 2_147_483_648 ],
    [ "LENOVO", "ThinkPad X220", "x220-b", "Intel Core i5-2520M", 8_589_934_592 ],
    [ "LENOVO", "ThinkPad X220", "x220-c", "Intel Core i7-2620M", 8_589_934_592 ],
    [ "LENOVO", "ThinkPad X230", "x230-a", "Intel Core i5-3320M", 8_589_934_592 ],
    [ "Framework", "Laptop 13", "framework-13-a", "Intel Core i7-1360P", 17_179_869_184 ]
  ].each do |vendor, product, key, cpu_model, memory_bytes|
    ensure_report(vendor: vendor, product: product, key: key, cpu_model: cpu_model, memory_bytes: memory_bytes)
  end

  puts "Development admin: admin@example.com / #{password}"
end
