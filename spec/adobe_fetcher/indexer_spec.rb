# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"
require "zip"

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

  it "builds v1 and v2 together, with structured pubid ids keyed to files" do
    write_yaml("atn5014")
    write_publication("adobe-glyph-list", "Adobe Glyph List")

    described_class.build(
      data_dir: data_dir, index_file: index_file, index_v2_file: index_v2_file,
    )

    # Both flavours are written in one pass — no pool/file collision.
    expect(File).to exist(index_file)
    by_type = index_v2_by_type

    expect(by_type.fetch("pubid:adobe:tech-note")).to match(
      id: include("number" => "5014"), file: end_with("atn5014.yaml"),
    )
    expect(by_type.fetch("pubid:adobe:publication")).to match(
      id: include("slug" => "adobe-glyph-list"), file: end_with("adobe-glyph-list.yaml"),
    )
  end

  it "warns and continues when a file has no docidentifier" do
    store.write("broken", { "type" => "standard", "title" => [] })
    expect { described_class.build(data_dir: data_dir, index_file: index_file) }
      .to output(/no docidentifier/).to_stderr
  end

  it "zips each index into a sibling .zip holding the yaml at its basename" do
    File.write(index_file, "--- []\n", encoding: "UTF-8")
    File.write(index_v2_file, "--- v2\n", encoding: "UTF-8")

    described_class.zip(index_file, index_v2_file)

    [index_file, index_v2_file].each do |yaml|
      expect(zip_entries(yaml.sub(/\.yaml\z/, ".zip")))
        .to eq(File.basename(yaml) => File.read(yaml, encoding: "UTF-8"))
    end
  end

  it "rebuilds the zip cleanly when run again (no duplicate-entry error)" do
    File.write(index_file, "--- []\n", encoding: "UTF-8")
    described_class.zip(index_file)
    File.write(index_file, "--- [changed]\n", encoding: "UTF-8")

    expect { described_class.zip(index_file) }.not_to raise_error
    expect(zip_entries(index_file.sub(/\.yaml\z/, ".zip")))
      .to eq("index-v1.yaml" => "--- [changed]\n")
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

  # A named publication: docid.content is the title-based citation, but
  # id is the slug that Pubid::Adobe parses for index-v2.
  def write_publication(slug, title)
    store.write(slug, {
      "id" => slug,
      "type" => "standard",
      "title" => [{ "language" => "eng", "content" => title, "type" => "main" }],
      "docidentifier" => [{
        "content" => "Adobe Publication #{title}", "type" => "ADOBE", "primary" => true,
      }],
      "ext" => { "doctype" => { "content" => "publication" }, "flavor" => "adobe" },
    })
  end

  # index-v2 entries keyed by their pubid `_type`.
  def index_v2_by_type
    entries = YAML.safe_load(File.read(index_v2_file, encoding: "UTF-8"), permitted_classes: [Symbol])
    entries.each_with_object({}) { |e, h| h[e[:id]["_type"]] = e }
  end

  # { entry_name => content } for every member of a zip archive.
  def zip_entries(zip_path)
    Zip::File.open(zip_path).each_with_object({}) do |entry, h|
      h[entry.name] = entry.get_input_stream.read
    end
  end
end
