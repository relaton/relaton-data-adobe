#!/usr/bin/env ruby
# frozen_string_literal: true

# Round-trip validator: load each data/*.yaml through
# Relaton::Adobe::Item, re-serialize, and diff against the source.
# Exit 1 on any mismatch, on a missing primary docidentifier, or on a
# primary docidentifier that is not the canonical Pubid::Adobe form of
# the record's id (`Pubid::Adobe.parse(id).to_s`, e.g. "Adobe TN 5014",
# "Adobe Publication pdf-reference-1.7").
#
# Uses Relaton::Adobe::Item so the Adobe-specific ext fields (urn,
# webpage, tech_note_number, source_repo_path, publication_slug)
# round-trip natively — no merge hack.

require "relaton/adobe"
require "pubid"
require "pubid/adobe"

path = ARGV.first || "data/*.{yaml,yml}"

# The canonical Pubid::Adobe rendering of a record id, or a parse
# error message.
def canonical_render(content)
  Pubid::Adobe.parse(content).to_s
rescue StandardError => e
  "(parse error: #{e.message})"
end

errors = false
Dir[path].sort.each do |f|
  yaml = File.read(f, encoding: "UTF-8")
  item = Relaton::Adobe::Item.from_yaml(yaml)

  primary_id = item.docidentifier.find(&:primary)
  unless primary_id
    errors = true
    puts "Parsing #{f} failed. No primary docidentifier."
    next
  end

  rendered = canonical_render(item.id)
  unless rendered == primary_id.content
    errors = true
    puts "Non-canonical primary docidentifier in #{f}:"
    puts "  - #{primary_id.content}"
    puts "  + #{rendered}"
    puts
  end

  reserialized = item.to_yaml

  next if reserialized == yaml

  errors = true
  puts "Round-trip mismatch in #{f}:"
  src_lines = yaml.split("\n")
  out_lines = reserialized.split("\n")
  require "diff/lcs"
  Diff::LCS.sdiff(src_lines, out_lines).each do |change|
    next if change.action == "="

    case change.action
    when "-" then puts "  - #{change.old_element}"
    when "+" then puts "  + #{change.new_element}"
    when "!" then puts "  - #{change.old_element}\n  + #{change.new_element}"
    end
  end
  puts
rescue StandardError => e
  errors = true
  puts "Parsing #{f} failed: #{e.message}"
  puts e.backtrace.first(5)
  puts
end

exit(1) if errors
puts "OK: all data files round-trip cleanly."
