# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe AdobeFetcher::Indexer do
  let(:data_dir) { Dir.mktmpdir("adobe-index-data") }
  let(:tmp_root) { Dir.mktmpdir("adobe-index-root") }
  let(:index_file) { File.join(tmp_root, "index-v1.yaml") }
  let(:index_v2_file) { File.join(tmp_root, "index-v2.yaml") }
  let(:store) { AdobeFetcher::YamlStore.new(data_dir) }

  after do
    FileUtils.rm_rf(data_dir)
    FileUtils.rm_rf(tmp_root)
  end

  it "produces index-v1.yaml sorted by filename" do
    write_yaml("atn5902")
    write_yaml("atn5014")

    described_class.build(
      data_dir: data_dir, index_file: index_file, index_v2_file: nil,
    )

    contents = File.read(index_file)
    expect(contents).to include("atn5014")
    expect(contents).to include("atn5902")
    # v1 sorted by filename — 5014 should appear before 5902.
    expect(contents.index("atn5014")).to be < contents.index("atn5902")
  end

  it "produces index-v2.yaml with structured pubids" do
    write_yaml("atn5014")

    described_class.build(
      data_dir: data_dir, index_file: index_file, index_v2_file: index_v2_file,
    )

    v2 = File.read(index_v2_file)
    expect(v2).to include("pubid:adobe:tech-note")
    expect(v2).to include("5014")
  end

  it "parses publication id (slug-form) for index-v2 even when docid.content uses title" do
    # Simulate a named publication: docid.content is the title-based
    # citation, but id is the slug. The indexer should use id (not
    # docid.content) so Pubid::Adobe parses cleanly.
    hash = {
      "id" => "adobe-glyph-list",
      "type" => "standard",
      "title" => [{ "language" => "eng", "content" => "Adobe Glyph List", "type" => "main" }],
      "docidentifier" => [{
        "content" => "Adobe Publication Adobe Glyph List",
        "type" => "ADOBE", "primary" => true,
      }],
      "ext" => { "doctype" => { "content" => "publication" }, "flavor" => "adobe" },
    }
    store.write("adobe-glyph-list", hash)

    described_class.build(
      data_dir: data_dir, index_file: index_file, index_v2_file: index_v2_file,
    )

    v2 = File.read(index_v2_file)
    expect(v2).to include("pubid:adobe:publication")
    expect(v2).to include("adobe-glyph-list")
  end

  it "warns and continues when a file has no docidentifier" do
    store.write("broken", { "type" => "standard", "title" => [] })
    expect { described_class.build(data_dir: data_dir, index_file: index_file) }
      .to output(/no docidentifier/).to_stderr
  end

  def write_yaml(stem)
    hash = {
      "id" => stem.upcase,
      "type" => "standard",
      "title" => [{ "language" => "eng", "content" => "Test", "type" => "main" }],
      "docidentifier" => [{
        "content" => "Adobe TN #{stem[/\d+/]}",
        "type" => "ADOBE", "primary" => true,
      }],
      "ext" => { "doctype" => { "content" => "tech-note" }, "flavor" => "adobe" },
    }
    store.write(stem, hash)
  end
end
