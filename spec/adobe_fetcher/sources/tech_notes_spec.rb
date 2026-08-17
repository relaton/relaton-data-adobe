# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe AdobeFetcher::Sources::TechNotes do
  let(:clone_dir) { Dir.mktmpdir("tech-notes-spec") }

  before do
    pdfs = File.join(clone_dir, "pdfs")
    FileUtils.mkdir_p(pdfs)
    %w[5014.CIDFont_Spec.pdf 5902.AdobePSNameGeneration.pdf].each do |f|
      FileUtils.touch(File.join(pdfs, f))
    end
    # An unrecognized shape: must be skipped, not fatal.
    FileUtils.touch(File.join(pdfs, "README.md"))

    # Real local git remote + tracking branch so ensure_clone's
    # pull-on-existing path runs offline.
    @remote_dir = Dir.mktmpdir("tn-remote")
    @remote = File.join(@remote_dir, "origin.git")
    system("git init --bare -q #{@remote}")
    system("git -C #{clone_dir} init -q -b main")
    system("git -C #{clone_dir} add .")
    system("git -C #{clone_dir} -c user.email=spec@example.com " \
           "-c user.name=spec commit -qm fixture")
    system("git -C #{clone_dir} remote add origin #{@remote}")
    system("git -C #{clone_dir} push -q origin main")
    system("git -C #{clone_dir} branch --set-upstream-to=origin/main main")
  end

  after do
    FileUtils.rm_rf(clone_dir)
    FileUtils.rm_rf(@remote_dir)
  end

  it "yields one entry per recognized PDF, sorted by number" do
    entries = described_class.new(clone_dir: clone_dir).each_entry.to_a

    expect(entries.map(&:number)).to eq(%w[5014 5902])
    expect(entries.map(&:slug)).to eq(%w[CIDFont_Spec AdobePSNameGeneration])
  end

  it "carries the pdfs/ repo path and web links" do
    entry = described_class.new(clone_dir: clone_dir).each_entry.first

    expect(entry.filename).to eq("5014.CIDFont_Spec.pdf")
    expect(entry.web_url).to eq(
      "https://github.com/adobe-type-tools/font-tech-notes/blob/main/pdfs/5014.CIDFont_Spec.pdf",
    )
    expect(entry.bytes_url).to eq(
      "https://github.com/adobe-type-tools/font-tech-notes/raw/main/pdfs/5014.CIDFont_Spec.pdf",
    )
  end

  it "returns an Enumerator when called without a block" do
    expect(described_class.new(clone_dir: clone_dir).each_entry)
      .to be_a(Enumerator)
  end
end
