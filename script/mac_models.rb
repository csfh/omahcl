#!/usr/bin/env ruby
# Rebuilds config/mac_models.yml from Apple's "Identify your <line>" support pages.
#
#   ruby script/mac_models.rb
#
# Each page lists a Mac's name and its Model Identifier. The merge rules:
#   - An identifier sold in several years shows the span: "Retina, 15-inch, 2012–2013".
#   - If one identifier covers several sizes (iMac9,1 is 20- and 24-inch), the size is
#     dropped and the year kept. GHz variants are dropped the same way.
#   - Server and Rack variants are left out, unless they are all there is.
#   - If names still differ, the shortest is used and the script says so.
# Not loaded by the app. Review the diff before committing.
require "net/http"
require "uri"
require "yaml"

PAGES = {
  "MacBook Pro" => 108052, "MacBook Air" => 102869, "MacBook" => 103257,
  "iMac" => 108054, "Mac mini" => 102852, "Mac Pro" => 102887, "Mac Studio" => 102231
}.freeze
YEAR = /,?\s*(?:(?:Early|Mid|Late) )?(\d{4})(?=[,)])/
OUTPUT = File.expand_path("../config/mac_models.yml", __dir__)

def fetch(id)
  response = Net::HTTP.get_response(URI("https://support.apple.com/en-us/#{id}"))
  abort "Apple page #{id}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
  response.body.force_encoding(Encoding::UTF_8)
end

def clean(text)
  text.gsub(/<[^>]+>/, "").gsub(/&nbsp;| /, " ").gsub("&amp;", "&").gsub(/\s+/, " ").strip
end

# identifier => every heading it appears under
def scrape(html, names)
  html.scan(%r{<b>\s*Model Identifier:\s*</b>\s*([^<]*)<}) do |(listed)|
    # Read the match before anything else scans, which resets it.
    position = Regexp.last_match.begin(0)
    heading = clean(html[0, position].scan(%r{<h[1-4][^>]*>(.*?)</h[1-4]>}m).last&.first.to_s)
    next if heading.empty?
    listed.scan(/[A-Za-z]+\d+,\d+/).each { |id| (names[id] ||= []) << heading }
  end
end

def stem(name, drop_sizes)
  text = name.gsub(/,?\s*\d+\.\d+GHz(?=[,)])/, "")
  text = text.gsub(/(?<=\(|, )\d+(?:\.\d+)?-inch,?\s*/, "") if drop_sizes
  text.gsub(YEAR, "").sub(/\s*\(\)/, "").gsub(/\(,\s*/, "(").gsub(/,\s*\)/, ")")
end

def merge(id, names)
  names = names.uniq
  names = names.reject { |name| name =~ /Server|Rack/ }.then { |kept| kept.empty? ? names : kept }
  return names.first if names.size == 1

  years = names.map { |name| name[YEAR, 1].to_i }
  stems = [ false, true ].map { |drop| names.map { |name| stem(name, drop) } }.find { |set| set.uniq.size == 1 }
  if stems && years.all?(&:positive?)
    span = years.min == years.max ? years.min.to_s : "#{years.min}–#{years.max}"
    base = stems.first
    base.end_with?(")") ? base.sub(/\)\z/, ", #{span})") : "#{base} (#{span})"
  else
    warn "#{id}: names differ, using the shortest of #{names.inspect}"
    names.min_by(&:length)
  end
end

names = {}
PAGES.each { |line, id| scrape(fetch(id), names).tap { warn "#{line}: page #{id} read" } }
table = names.to_h { |id, headings| [ id, merge(id, headings) ] }.sort.to_h

header = <<~YAML
  # Mac model identifier => marketing name, for Intel-era and newer Macs.
  # Built from Apple's "Identify your <line>" support pages (MacBook Pro, MacBook Air,
  # MacBook, iMac, Mac mini, Mac Pro, Mac Studio) in October 2026 by script/mac_models.rb.
  # An identifier sold in several years shows the span ("2012–2013"). Server and Rack
  # variants are left out. Report::Display.model looks a report's product up here;
  # unknown ones show as sent.
YAML
File.write(OUTPUT, header + table.to_yaml(line_width: -1).sub(/\A---\n/, ""))
puts "Wrote #{table.size} identifiers to #{OUTPUT}"
