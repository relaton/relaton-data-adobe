# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe AdobeFetcher::YamlStore do
  let(:dir) { Dir.mktmpdir("adobe-yaml-store") }
  let(:store) { described_class.new(dir) }

  after { FileUtils.rm_rf(dir) }

  it "writes a YAML file under the directory" do
    store.write("atn5014", minimal_hash)
    expect(File.exist?(File.join(dir, "atn5014.yaml"))).to be(true)
  end

  it "is idempotent — skips when overwrite: false and file exists" do
    store.write("atn5014", minimal_hash)
    expect(store.write("atn5014", minimal_hash, overwrite: false)).to be(false)
  end

  it "round-trips a hash through write → read" do
    store.write("atn5014", minimal_hash)
    data = store.read("atn5014")
    expect(data["docidentifier"].first["content"])
      .to eq("Adobe TN 5014")
  end

  it "exposes each_yaml as an iterator over the directory" do
    store.write("atn5014", minimal_hash)
    keys = store.each_yaml.map { |name, _path| name }
    expect(keys).to include("atn5014")
  end

  it "reports existence via exist?" do
    expect(store.exist?("atn5014")).to be(false)
    store.write("atn5014", minimal_hash)
    expect(store.exist?("atn5014")).to be(true)
  end

  it "patch yields the parsed hash for in-place mutation" do
    store.write("atn5014", minimal_hash)
    store.patch("atn5014") { |data| data["touched"] = true }
    expect(store.read("atn5014")["touched"]).to be(true)
  end

  def minimal_hash
    {
      "id" => "ATN5014",
      "type" => "standard",
      "title" => [{
        "language" => "eng", "content" => "Test Note", "type" => "main",
      }],
      "docidentifier" => [{
        "content" => "Adobe TN 5014",
        "type" => "ADOBE", "primary" => true,
      }],
      "ext" => { "doctype" => { "content" => "tech-note" }, "flavor" => "adobe" },
    }
  end
end
