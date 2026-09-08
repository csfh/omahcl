DonationDestination.find_or_create_by!(name: "Omacom Foundation") do |destination|
  destination.url = "https://donate.omarchy.org"
  destination.description = "Patronage and support for Omarchy through the Omacom Foundation."
  destination.active = true
end
