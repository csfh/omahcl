ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

env_path = File.expand_path("../.env", __dir__)
if File.exist?(env_path)
  File.foreach(env_path) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, _sep, value = line.partition("=")
    next if key.empty?
    ENV[key] ||= value.delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'")
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
