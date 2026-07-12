# frozen_string_literal: true

require "spec_helper"
require "date"

RSpec.describe AdobeFetcher::CoverPageParser do
  describe ".parse" do
    it "extracts number, title, edition, date from a canonical Adobe TN cover" do
      text = <<~TEXT
        Adobe TN 5014
        Adobe CMap and CID Font Files Specification
        Version 1.0
        11 June 1993
      TEXT
      result = described_class.parse(text)
      expect(result.number).to eq("5014")
      expect(result.title).to eq("Adobe CMap and CID Font Files Specification")
      expect(result.edition).to eq("1.0")
      expect(result.date).to eq(Date.new(1993, 6, 11))
    end

    it "handles the legacy 'Adobe Technical Note #' form (back-compat)" do
      text = "Adobe Technical Note #5014\nTitle\nVersion 1.0"
      result = described_class.parse(text)
      expect(result.number).to eq("5014")
    end

    it "handles Adobe TN without a space (Adobe TN5014)" do
      result = described_class.parse("Adobe TN5014\nTitle")
      expect(result.number).to eq("5014")
    end

    it "handles the ATN short form" do
      result = described_class.parse("ATN5902\nTitle Here")
      expect(result.number).to eq("5902")
    end

    it "handles month-year date form" do
      text = "Adobe TN 5176\nThe Compact Font Format Specification\nVersion 1.0\nDecember 2003"
      result = described_class.parse(text)
      expect(result.date).to eq(Date.new(2003, 12, 1))
    end

    it "captures the URN line when present" do
      text = "Adobe TN 5014\nTitle\nurn:adobe:tech-note:5014"
      result = described_class.parse(text)
      expect(result.urn).to eq("urn:adobe:tech-note:5014")
    end

    it "handles Edition as well as Version" do
      result = described_class.parse("Adobe TN 5004\nTitle\nEdition 2.1\nJune 1992")
      expect(result.edition).to eq("2.1")
    end

    it "raises on empty input" do
      expect { described_class.parse("") }
        .to raise_error(AdobeFetcher::CoverPageParser::MissingCoverFields)
    end

    it "handles 'Month Day, Year' date form" do
      result = described_class.parse("Adobe TN 5660\nTitle\nJanuary 15, 2000")
      expect(result.date).to eq(Date.new(2000, 1, 15))
    end
  end
end
