# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe AdobeFetcher::PdfDownloader do
  let(:cache_dir) { Dir.mktmpdir("adobe-pdfs") }
  let(:fake_http) { AdobeFetcher::Http::Fake.new(url => "%PDF-1.4 fake") }
  let(:url) { "https://raw.example.com/5014.CIDFont_Spec.pdf" }
  let(:downloader) { described_class.new(cache_dir: cache_dir, http_backend: fake_http) }

  after { FileUtils.rm_rf(cache_dir) }

  it "downloads and caches the PDF under <name>.pdf" do
    path = downloader.fetch(url, name: "atn5014")
    expect(File.basename(path)).to eq("atn5014.pdf")
    expect(File.binread(path)).to eq("%PDF-1.4 fake")
  end

  it "is idempotent — does not re-download on second call" do
    path = downloader.fetch(url, name: "atn5014")
    first_mtime = File.mtime(path)
    sleep 0.01
    downloader.fetch(url, name: "atn5014")
    expect(File.mtime(path)).to eq(first_mtime)
  end

  it "records the URL in the manifest" do
    downloader.fetch(url, name: "atn5014")
    expect(downloader.url_for("atn5014")).to eq(url)
  end

  it "reports cached? correctly" do
    expect(downloader.cached?("atn5014")).to be(false)
    downloader.fetch(url, name: "atn5014")
    expect(downloader.cached?("atn5014")).to be(true)
  end

  it "sanitises unsafe name characters" do
    path = downloader.fetch(url, name: "name with spaces/slashes")
    expect(File.basename(path)).to eq("name_with_spaces_slashes.pdf")
  end
end
