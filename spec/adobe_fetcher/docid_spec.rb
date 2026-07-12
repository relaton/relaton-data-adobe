# frozen_string_literal: true

require "spec_helper"

RSpec.describe AdobeFetcher::Docid do
  describe ".from_tech_note_number" do
    it "builds a typed TechNote Docid from a numeric argument" do
      d = described_class.from_tech_note_number(5014)
      expect(d.code).to eq("ATN5014")
      expect(d.typed).to be(true)
      expect(d.doctype).to eq("tech-note")
      expect(d.tech_note_number).to eq("5014")
    end

    it "accepts a numeric string" do
      d = described_class.from_tech_note_number("5902")
      expect(d.tech_note_number).to eq("5902")
    end

    it "preserves the slug when supplied" do
      d = described_class.from_tech_note_number(5014, slug: "CIDFont_Spec")
      expect(d.slug).to eq("CIDFont_Spec")
    end

    it "raises on non-numeric input" do
      expect { described_class.from_tech_note_number("not-a-number") }
        .to raise_error(ArgumentError)
    end
  end

  describe ".from_filename" do
    it "parses the standard filename form" do
      d = described_class.from_filename("5014.CIDFont_Spec.pdf")
      expect(d.tech_note_number).to eq("5014")
      expect(d.slug).to eq("CIDFont_Spec")
    end

    it "parses filenames with underscores in the slug" do
      d = described_class.from_filename("5004.AFM_Spec.pdf")
      expect(d.tech_note_number).to eq("5004")
      expect(d.slug).to eq("AFM_Spec")
    end

    it "raises on filenames that don't match the convention" do
      expect { described_class.from_filename("README.md") }
        .to raise_error(ArgumentError)
    end

    it "strips directory components" do
      d = described_class.from_filename("pdfs/5902.AdobePSNameGeneration.pdf")
      expect(d.tech_note_number).to eq("5902")
    end
  end

  describe ".from_slug" do
    it "builds a generic publication Docid" do
      d = described_class.from_slug("adobe-glyph-list")
      expect(d.code).to eq("adobe-glyph-list")
      expect(d.typed).to be(false)
      expect(d.doctype).to eq("publication")
    end

    it "accepts an optional version" do
      d = described_class.from_slug("adobe-japan1", version: 7)
      expect(d.slug).to eq("adobe-japan1")
      expect(d.version).to eq("7")
    end

    it "accepts an optional title" do
      d = described_class.from_slug("adobe-glyph-list", title: "Adobe Glyph List")
      expect(d.title).to eq("Adobe Glyph List")
    end
  end

  describe ".from_string" do
    it "routes Adobe TN strings to typed Docids" do
      d = described_class.from_string("Adobe TN 5014")
      expect(d.typed).to be(true)
      expect(d.tech_note_number).to eq("5014")
    end

    it "routes legacy Adobe Technical Note strings (back-compat)" do
      d = described_class.from_string("Adobe Technical Note #5014")
      expect(d.typed).to be(true)
      expect(d.tech_note_number).to eq("5014")
    end

    it "routes Adobe Publication <slug> strings to generic Docids" do
      d = described_class.from_string("Adobe Publication adobe-glyph-list")
      expect(d.typed).to be(false)
      expect(d.slug).to eq("adobe-glyph-list")
    end

    it "routes bare slug strings (back-compat)" do
      d = described_class.from_string("adobe-glyph-list")
      expect(d.typed).to be(false)
      expect(d.slug).to eq("adobe-glyph-list")
    end
  end

  describe "#to_s" do
    it "renders the canonical Adobe TN form for tech notes" do
      expect(described_class.from_tech_note_number(5014).to_s)
        .to eq("Adobe TN 5014")
    end

    it "renders the Adobe Publication form with slug when no title" do
      expect(described_class.from_slug("adobe-glyph-list").to_s)
        .to eq("Adobe Publication adobe-glyph-list")
    end

    it "renders the Adobe Publication form with title when present" do
      d = described_class.from_slug("adobe-glyph-list", title: "Adobe Glyph List")
      expect(d.to_s).to eq("Adobe Publication Adobe Glyph List")
    end

    it "includes the version suffix for versioned publications without title" do
      d = described_class.from_slug("adobe-japan1", version: 7)
      expect(d.to_s).to eq("Adobe Publication adobe-japan1-7")
    end
  end

  describe "#filename_stem" do
    it "is lowercase and filesystem-safe" do
      expect(described_class.from_tech_note_number(5014).filename_stem)
        .to eq("atn5014")
    end

    it "uses dash-separated slug-version for publications" do
      d = described_class.from_slug("adobe-japan1", version: 7)
      expect(d.filename_stem).to eq("adobe-japan1-7")
    end
  end

  describe "#urn" do
    it "delegates to Pubid::Adobe for tech notes" do
      expect(described_class.from_tech_note_number(5014).urn)
        .to eq("urn:adobe:tech-note:5014")
    end

    it "delegates to Pubid::Adobe for publications" do
      expect(described_class.from_slug("adobe-glyph-list").urn)
        .to eq("urn:adobe:publication:adobe-glyph-list")
    end

    it "includes the version segment for versioned publications" do
      d = described_class.from_slug("adobe-japan1", version: 7)
      expect(d.urn).to eq("urn:adobe:publication:adobe-japan1:v7")
    end
  end

  describe "#id" do
    it "uses ATN<number> for tech notes" do
      expect(described_class.from_tech_note_number(5014).id).to eq("ATN5014")
    end

    it "uses <slug>-<version> (dash-separated) for versioned publications" do
      d = described_class.from_slug("adobe-japan1", version: 7)
      expect(d.id).to eq("adobe-japan1-7")
    end
  end

  describe "#with_title" do
    it "returns a new frozen instance with the title set" do
      original = described_class.from_slug("adobe-glyph-list")
      updated = original.with_title("Adobe Glyph List")
      expect(updated.title).to eq("Adobe Glyph List")
      expect(original.title).to be_nil
      expect(updated).to be_frozen
    end
  end

  describe "equality" do
    it "treats identical Docids as equal" do
      a = described_class.from_tech_note_number(5014)
      b = described_class.from_tech_note_number(5014)
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "distinguishes Docids with different slugs" do
      a = described_class.from_tech_note_number(5014, slug: "A")
      b = described_class.from_tech_note_number(5014, slug: "B")
      expect(a).not_to eq(b)
    end

    it "distinguishes Publications with different titles" do
      a = described_class.from_slug("adobe-glyph-list", title: "X")
      b = described_class.from_slug("adobe-glyph-list", title: "Y")
      expect(a).not_to eq(b)
    end
  end

  it "is frozen on construction" do
    expect(described_class.from_tech_note_number(5014)).to be_frozen
  end
end
