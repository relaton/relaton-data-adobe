# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe AdobeFetcher::PublicationFetcher do
  let(:data_dir) { Dir.mktmpdir("adobe-data") }
  let(:store) { AdobeFetcher::YamlStore.new(data_dir) }
  let(:source) { FakeSource.new(entries) }

  after { FileUtils.rm_rf(data_dir) }

  it "emits one YAML per source entry" do
    fetcher = described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [source],
    )
    fetcher.run

    files = Dir[File.join(data_dir, "*.yaml")].sort
    expect(files.length).to eq(2)
    expect(File.basename(files.first)).to eq("atn5014.yaml")
  end

  it "writes the canonical docidentifier content" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [source],
    ).run

    data = store.read("atn5014")
    expect(data["docidentifier"].first["content"])
      .to eq("Adobe TN 5014")
    expect(data["docidentifier"].first["primary"]).to be(true)
  end

  it "writes the Adobe ext block with urn and source_repo_path" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [source],
    ).run

    data = store.read("atn5014")
    expect(data["ext"]["urn"]).to eq("urn:adobe:tech-note:5014")
    expect(data["ext"]["tech_note_number"]).to eq("5014")
    expect(data["ext"]["source_repo_path"])
      .to eq("pdfs/5014.CIDFont_Spec.pdf")
    expect(data["ext"]["flavor"]).to eq("adobe")
    expect(data["ext"]["doctype"]["content"]).to eq("tech-note")
  end

  it "emits a record even when the source has no PDF / cover" do
    described_class.new(
      data_dir: data_dir, yaml_store: store, sources: [source],
    ).run

    data = store.read("atn5902")
    expect(data["title"].first["content"])
      .to eq("AdobePSNameGeneration") # title-cased from the slug
  end

  # Lightweight fake source — replaces Sources::TechNotes for orchestration
  # tests. Real instances only; no doubles.
  class FakeSource < AdobeFetcher::Sources::Base
    def initialize(entries_data)
      @entries_data = entries_data
    end

    def each_entry
      return enum_for(:each_entry) unless block_given?

      @entries_data.each { |d| yield AdobeFetcher::SourceEntry.new(**d) }
    end
  end

  def entries
    [
      { number: "5014", slug: "CIDFont_Spec", filename: "5014.CIDFont_Spec.pdf",
        web_url: "https://example.com/5014", bytes_url: "https://example.com/5014.pdf" },
      { number: "5902", slug: "AdobePSNameGeneration", filename: "5902.AdobePSNameGeneration.pdf",
        web_url: "https://example.com/5902", bytes_url: "https://example.com/5902.pdf" },
    ]
  end
end
