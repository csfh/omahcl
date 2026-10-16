namespace :admin do
  desc "Create an admin, or reset an admin's password. EMAIL=you@example.com [PASSWORD=...]"
  task create: :environment do
    email = ENV["EMAIL"].to_s.strip
    abort "EMAIL is required" if email.empty?

    password = ENV["PASSWORD"].presence || SecureRandom.base58(20)
    user = User.find_or_initialize_by(email_address: email)
    user.assign_attributes(password: password, password_confirmation: password, admin: true)
    user.save!

    puts "Admin #{user.email_address} is ready."
    puts "Password: #{password}" if ENV["PASSWORD"].blank?
  end
end
