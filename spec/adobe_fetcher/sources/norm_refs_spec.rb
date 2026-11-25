# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe AdobeFetcher::Sources::NormRefs do
  it "yields the curated tech notes with their citation metadata" do
    entries = described_class.new.each_entry.select(&:number)

    expect(entries.map(&:number)).to eq(%w[5001 5044 5116 5411 5620 5660])
    atn5116 = entries.find { |e| e.number == "5116" }
    expect(atn5116.title).to eq("Supporting the DCT Filters in PostScript Level 2")
    expect(atn5116.date).to eq("1992-11")
    expect(atn5116.bytes_url).to eq("https://www.pdfa.org/norm-refs/5116.DCT_Filter.pdf")
  end

  it "yields the curated publications with slug+version" do
    entries = described_class.new.each_entry.reject(&:number)

    expect(entries.map(&:slug)).to eq([
      "postscript-language-reference", "pdf-signature-build-dictionary",
      "tiff", "xfa", "adobe-glyph-list", "adobe-glyph-list-for-new-fonts",
      "adobe-japan1", "adobe-gb1", "pdf-reference", "adobe-supplement-iso32000",
    ])
    xfa = entries.find { |e| e.slug == "xfa" }
    expect(xfa.version).to eq("3.3")
    expect(xfa.title).to include("XML Forms Architecture")
    expect(xfa.web_url).to eq(xfa.bytes_url)
  end

  describe "the publications with no crawlable copy" do
    let(:archive) { "https://pdfa.org/resource/pdf-specification-archive/" }
    let(:entries) { described_class.new.each_entry.to_a }

    it "curates PDF Reference 1.1 in the form of the PdfStandards siblings" do
      pdf11 = entries.find { |e| e.slug == "pdf-reference" }

      expect(pdf11.to_docid.to_s).to eq("Adobe Publication pdf-reference-1.1")
      expect(pdf11.title)
        .to eq("PDF Reference: Adobe Portable Document Format, Version 1.1")
      expect(pdf11.date).to eq("1996-01-23")
      expect(pdf11.bytes_url).to be_nil
      expect(pdf11.web_url).to eq(archive)
    end

    it "curates the ExtensionLevel 5 Supplement under a non-numeric slug" do
      supplement = entries.find { |e| e.slug == "adobe-supplement-iso32000" }
      id = supplement.to_docid.to_s
      pubid = Pubid::Adobe.parse(id)

      expect(id).to eq("Adobe Publication adobe-supplement-iso32000-5")
      expect(pubid.to_s).to eq(id)
      expect([pubid.slug, pubid.version]).to eq(["adobe-supplement-iso32000", "5"])
      expect(supplement.title).to eq(
        "Adobe Supplement to the ISO 32000, BaseVersion 1.7, ExtensionLevel 5",
      )
      expect(supplement.date).to eq("2009-06")
      expect(supplement.bytes_url).to be_nil
      expect(supplement.web_url).to eq(archive)
    end
  end

  it "round-trips every entry through its Docid" do
    described_class.new.each_entry do |entry|
      docid = entry.to_docid
      expect(docid.id).not_to be_empty
      expect(docid.urn).to start_with("urn:adobe:")
    end
  end
end

RSpec.describe AdobeFetcher::Sources::PdfStandards do
  let(:tree_response) do
    JSON.generate(
      "tree" => [
        { "path" => "docs/pdfstandards/pdfreference1.0.pdf" },
        { "path" => "docs/pdfstandards/pdfreference1.5_v6.pdf" },
        { "path" => "docs/pdfstandards/pdfreference1.7old.pdf" },
        { "path" => "docs/pdfstandards/PDF32000_2008.pdf" },
        { "path" => "docs/pdfstandards/readme.txt" },
        { "path" => "docs/library/distiller/index.html" },
      ],
    )
  end

  let(:source) do
    backend = Class.new do
      def initialize(body)
        @body = body
      end

      def get(_url, **)
        @body
      end
    end
    described_class.new(http: backend.new(tree_response))
  end

  it "yields the reference editions from the repository listing" do
    entries = source.each_entry.to_a

    expect(entries.map(&:version)).to eq(%w[1.0 1.5 1.7])
    expect(entries.map(&:slug).uniq).to eq(["pdf-reference"])
    expect(entries.first.title).to include("PDF Reference")
    expect(entries.first.date).to eq("1993")
  end

  it "skips the ISO-authored PDF32000 text" do
    expect(source.each_entry.to_a.map(&:version)).not_to include("2008")
  end

  it "points bytes_url at the raw copy and web_url at the blob page" do
    entry = source.each_entry.to_a.first

    expect(entry.bytes_url)
      .to eq("https://raw.githubusercontent.com/adobe/dc-acrobat-sdk-docs/master/" \
             "docs/pdfstandards/pdfreference1.0.pdf")
    expect(entry.web_url)
      .to start_with("https://github.com/adobe/dc-acrobat-sdk-docs/blob/master/")
    expect(entry.source_repo_path).to eq("docs/pdfstandards/pdfreference1.0.pdf")
  end

  it "survives a malformed listing with no entries" do
    backend = Class.new do
      def get(_url, **)
        "not json"
      end
    end
    expect(described_class.new(http: backend.new).each_entry.to_a).to be_empty
  end
end
