DonationDestination.find_or_create_by!(name: "Omacom Foundation") do |destination|
  destination.url = "https://donate.omarchy.org"
  destination.description = "Patronage and support for Omarchy through the Omacom Foundation."
  destination.active = true
end

if Rails.env.development?
  def ensure_user(email, password:, admin: false)
    user = User.find_or_initialize_by(email_address: email)
    user.password = password
    user.password_confirmation = password
    user.admin = admin
    user.email_verified_at ||= Time.current
    user.save!
    user
  end

  def ensure_claimed_report(user:, vendor:, product:, key:, cpu_model:, memory_bytes:)
    digest = Digest::SHA256.hexdigest("market-seed:#{key}")
    report = Report.find_or_initialize_by(instance_digest: digest)
    report.assign_attributes(
      omarchy_version: "4.0.2",
      omarchy_channel: "stable",
      vendor: vendor,
      product: product,
      cpu_model: cpu_model,
      cpu_vendor: "Intel",
      cpu_arch: "x86_64",
      cpu_cores: 2,
      memory_bytes: memory_bytes,
      gpus: [ { "vendor" => "Intel", "name" => "HD Graphics 3000" } ],
      uefi: true,
      facts: {},
      user: user,
      claimed_at: report.claimed_at || Time.current
    )
    report.save!
    report
  end

  password = "password"
  one = ensure_user("one@example.com", password: password)
  two = ensure_user("two@example.com", password: password)
  ensure_user("admin@example.com", password: password, admin: true)

  ensure_claimed_report(
    user: one,
    vendor: "LENOVO",
    product: "ThinkPad X220",
    key: "x220-one",
    cpu_model: "Intel Core i5-2520M",
    memory_bytes: 2_147_483_648
  )
  ensure_claimed_report(
    user: two,
    vendor: "LENOVO",
    product: "ThinkPad X230",
    key: "x230-two",
    cpu_model: "Intel Core i5-3320M",
    memory_bytes: 8_589_934_592
  )
  ensure_claimed_report(
    user: one,
    vendor: "Framework",
    product: "Laptop 13",
    key: "framework-13-one",
    cpu_model: "Intel Core i7-1360P",
    memory_bytes: 17_179_869_184
  )

  puts "Development logins (password: #{password}):"
  puts "  one@example.com"
  puts "  two@example.com"
  puts "  admin@example.com (admin)"
end
