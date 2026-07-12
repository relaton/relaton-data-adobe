# frozen_string_literal: true

require "spec_helper"

RSpec.describe AdobeFetcher::SourceEntry do
  describe "#to_docid" do
    it "builds a TechNote Docid when number is present" do
      entry = described_class.new(number: "5014", slug: "CIDFont_Spec")
      docid = entry.to_docid
      expect(docid.typed).to be(true)
      expect(docid.tech_note_number).to eq("5014")
      expect(docid.slug).to eq("CIDFont_Spec")
    end

    it "builds a Publication Docid when only slug is present" do
      entry = described_class.new(slug: "adobe-glyph-list")
      docid = entry.to_docid
      expect(docid.typed).to be(false)
      expect(docid.slug).to eq("adobe-glyph-list")
    end

    it "passes version through for versioned publications" do
      entry = described_class.new(slug: "adobe-japan1", version: "7")
      expect(entry.to_docid.version).to eq("7")
    end

    it "passes title through to Publication Docids" do
      entry = described_class.new(slug: "adobe-glyph-list", title: "Adobe Glyph List")
      docid = entry.to_docid
      expect(docid.title).to eq("Adobe Glyph List")
      expect(docid.to_s).to eq("Adobe Publication Adobe Glyph List")
    end

    it "raises when neither number nor slug is set" do
      expect { described_class.new.to_docid }
        .to raise_error(ArgumentError)
    end

    it "prefers number when both are set (tech-note shape)" do
      entry = described_class.new(number: "5014", slug: "anything")
      expect(entry.to_docid.typed).to be(true)
    end
  end

  describe "accessors" do
    it "defaults every location field to nil" do
      entry = described_class.new(number: "5014")
      expect(entry.absolute_path).to be_nil
      expect(entry.web_url).to be_nil
      expect(entry.bytes_url).to be_nil
      expect(entry.filename).to be_nil
      expect(entry.version).to be_nil
      expect(entry.title).to be_nil
    end

    it "exposes every field passed to new" do
      entry = described_class.new(
        number: "5014", slug: "CIDFont_Spec", filename: "5014.CIDFont_Spec.pdf",
        absolute_path: "/tmp/x.pdf", web_url: "https://x", bytes_url: "https://x/raw",
      )
      expect(entry.filename).to eq("5014.CIDFont_Spec.pdf")
      expect(entry.absolute_path).to eq("/tmp/x.pdf")
      expect(entry.web_url).to eq("https://x")
      expect(entry.bytes_url).to eq("https://x/raw")
    end
  end
end
