if Rails.env.development?
  def ensure_report(vendor:, product:, key:, cpu_model:, memory_bytes:, cpu_cores: 2, cpu_vendor: "Intel", cpu_arch: "x86_64",
                    chassis: "10", gpus: [ { "vendor" => "Intel", "name" => "HD Graphics 3000" } ], version: "4.0.2",
                    channel: "stable", uefi: true, tpm: false, secure_boot: false, created_at: nil)
    digest = Report.digest_instance(Digest::SHA256.hexdigest("market-seed:#{key}"))
    report = Report.find_or_initialize_by(instance_digest: digest)
    report.assign_attributes(
      omarchy_version: version,
      omarchy_channel: channel,
      vendor: vendor,
      product: product,
      chassis: chassis,
      cpu_model: cpu_model,
      cpu_vendor: cpu_vendor,
      cpu_arch: cpu_arch,
      cpu_cores: cpu_cores,
      memory_bytes: memory_bytes,
      gpus: gpus,
      uefi: uefi,
      tpm_present: tpm,
      secure_boot_enabled: secure_boot,
      facts: {}
    )
    report.created_at = created_at if created_at && report.new_record?
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

  # A spread of made-up machines so the home page charts have something to show.
  # Seeded, so every run produces the same set.
  intel_igpu = [ { "vendor" => "Intel", "name" => "Iris Xe Graphics" } ]
  amd_igpu = [ { "vendor" => "AMD", "name" => "Radeon Graphics" } ]
  hybrid = [ { "vendor" => "Intel", "name" => "UHD Graphics" }, { "vendor" => "NVIDIA", "name" => "GeForce RTX 3060" } ]
  desktop_gpu = [ { "vendor" => "NVIDIA", "name" => "GeForce RTX 4070" } ]
  models = [
    [ "LENOVO", "ThinkPad T14", "10", "AMD", "AMD Ryzen 7 PRO 5850U", 8, amd_igpu, 22 ],
    [ "LENOVO", "ThinkPad X1 Carbon", "10", "Intel", "Intel Core i7-1260P", 12, intel_igpu, 18 ],
    [ "Dell", "XPS 13 9310", "10", "Intel", "Intel Core i7-1185G7", 4, intel_igpu, 16 ],
    [ "Dell", "Precision 5570", "10", "Intel", "Intel Core i9-12900H", 14, hybrid, 6 ],
    [ "Framework", "Laptop 13", "10", "AMD", "AMD Ryzen 7 7840U", 8, amd_igpu, 17 ],
    [ "ASUS", "ROG Zephyrus G14", "10", "AMD", "AMD Ryzen 9 6900HS", 8, [ { "vendor" => "AMD", "name" => "Radeon 680M" }, { "vendor" => "NVIDIA", "name" => "GeForce RTX 3050" } ], 9 ],
    [ "HP", "EliteBook 840 G8", "10", "Intel", "Intel Core i5-1135G7", 4, intel_igpu, 7 ],
    [ "Apple", "MacBook Pro 15,1", "10", "Intel", "Intel Core i7-9750H", 6, [ { "vendor" => "AMD", "name" => "Radeon Pro 555X" } ], 3 ],
    [ "Micro-Star", "MS-7E07", "3", "AMD", "AMD Ryzen 7 7700X", 8, desktop_gpu, 8 ],
    [ "Gigabyte", "B650 AORUS ELITE", "3", "AMD", "AMD Ryzen 9 7950X", 16, desktop_gpu, 5 ],
    [ "Minisforum", "UM790 Pro", "35", "AMD", "AMD Ryzen 9 7940HS", 8, amd_igpu, 4 ]
  ]
  versions = [ [ "4.0.2", 5 ], [ "4.0.1", 3 ], [ "4.0.0", 2 ], [ "3.9.4", 1 ] ]
  memory_gib = [ 8, 16, 16, 16, 32, 32, 64 ]
  random = Random.new(42)
  today = Time.current

  models.each do |vendor, product, chassis, cpu_vendor, cpu_model, cores, gpus, count|
    count.times do |index|
      version = versions.flat_map { |name, weight| [ name ] * weight }.sample(random: random)
      ensure_report(
        vendor: vendor, product: product, key: "#{product.parameterize}-#{index}", cpu_model: cpu_model,
        memory_bytes: (memory_gib.sample(random: random) * 1024**3 * 0.97).to_i, cpu_cores: cores, cpu_vendor: cpu_vendor,
        chassis: chassis, gpus: gpus, version: version,
        channel: random.rand < 0.12 ? "edge" : "stable", uefi: random.rand < 0.95, tpm: random.rand < 0.8,
        secure_boot: random.rand < 0.25,
        created_at: today - random.rand(0..90).days - random.rand(0..23).hours
      )
    end
  end

  puts "Development admin: admin@example.com / #{password}"
end
