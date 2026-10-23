#!/usr/bin/env ruby
# Rebuilds config/vendor_logos.yml: the outline of each vendor's logo, by the vendor's
# address on /vendors (Report::Vendor.slug).
#
#   ruby script/vendor_logos.rb
#
# The outlines come from Simple Icons (https://simpleicons.org), pinned to one release.
# Its icon data is CC0; the brands belong to their owners, and the site only uses a logo
# to say which vendor a machine comes from. A vendor not listed here has no logo and is
# shown by name. The SVGs are downloaded data, so each one must be a single path in a
# 24x24 box made only of path commands and numbers, or the script stops.
# Not loaded by the app. Review the diff before committing.
require "net/http"
require "uri"
require "yaml"

RELEASE = "14.15.0"
# Our vendor slug => the icon's name at Simple Icons.
ICONS = {
  "acer" => "acer", "apple" => "apple", "asus" => "asus", "dell" => "dell",
  "framework" => "framework", "google" => "google", "hp" => "hp", "huawei" => "huawei",
  "lenovo" => "lenovo", "msi" => "msi", "razer" => "razer", "samsung" => "samsung",
  "system76" => "system76"
}.freeze
PATH_DATA = /\A[MmLlHhVvCcSsQqTtAaZz0-9eE.,\s+-]+\z/
OUTPUT = File.expand_path("../config/vendor_logos.yml", __dir__)

def fetch(icon)
  uri = URI("https://cdn.jsdelivr.net/npm/simple-icons@#{RELEASE}/icons/#{icon}.svg")
  response = Net::HTTP.get_response(uri)
  abort "#{icon}: #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  response.body
end

def outline(icon, svg)
  abort "#{icon}: not a 24x24 icon" unless svg.include?('viewBox="0 0 24 24"')
  paths = svg.scan(/<path\b[^>]*>/)
  abort "#{icon}: expected one path, got #{paths.size}" unless paths.size == 1
  data = paths.first[/\sd="([^"]+)"/, 1]
  abort "#{icon}: unexpected path data" unless data&.match?(PATH_DATA)
  data
end

logos = ICONS.to_h { |slug, icon| [ slug, outline(icon, fetch(icon)) ] }
File.write(OUTPUT, "# Built by script/vendor_logos.rb from Simple Icons #{RELEASE} (CC0). Brands belong to their owners.\n" + logos.to_yaml.delete_prefix("---\n"))
puts "Wrote #{logos.size} logos"
