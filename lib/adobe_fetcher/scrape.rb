# frozen_string_literal: true

require "thor"

module AdobeFetcher
  class Scrape < Thor
    def self.exit_on_failure? = true

    default_task :fetch

    desc "fetch", "Fetch Adobe publications from registered sources into data/"
    method_option :source, type: :string, repeatable: true,
                            desc: "Source name to fetch (e.g. tech-notes). Defaults to all."
    method_option :pdfs, type: :boolean, default: false,
                         desc: "Download PDFs and OCR cover pages for fields not in source metadata."
    method_option :data_dir, type: :string, default: "data"
    method_option :pdfs_dir, type: :string, default: "pdfs"
    method_option :clone_dir, type: :string,
                              default: AdobeFetcher::Sources::TechNotes::DEFAULT_CLONE_DIR,
                              desc: "Directory for the font-tech-notes git clone"
    def fetch
      sources = build_sources(options[:source], clone: options[:clone_dir])
      if sources.empty?
        say "No sources selected. Available: tech-notes", :red
        exit 1
      end

      store = AdobeFetcher::YamlStore.new(options[:data_dir])
      pdf_downloader = options[:pdfs] ? AdobeFetcher::PdfDownloader.new(cache_dir: options[:pdfs_dir]) : nil
      cover_ocr = options[:pdfs] ? AdobeFetcher::CoverPageOcr.new : nil

      say "Fetching Adobe publications (sources=#{sources.map(&:class).map(&:name).inspect}, pdfs=#{options[:pdfs]})", :cyan
      AdobeFetcher::PublicationFetcher.new(
        data_dir: options[:data_dir],
        yaml_store: store,
        sources: sources,
        pdf_downloader: pdf_downloader,
        cover_page_ocr: cover_ocr,
      ).run

      say "Rebuilding indexes...", :cyan
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    desc "index", "Rebuild index-v1.yaml + index-v2.yaml from data/*.yaml"
    def index
      load File.expand_path("crawler.rb", Dir.pwd)
    end

    private

    def build_sources(names, clone:)
      names = names.map(&:to_s)
      available = available_sources(clone: clone)
      selected = names.empty? ? available.values : names.filter_map { |n| available[n] }
      selected
    end

    # Source registry. Adding a new source = adding one entry here and
    # one Sources::<Name> file. OCP at the source level.
    def available_sources(clone:)
      {
        "tech-notes" => AdobeFetcher::Sources::TechNotes.new(clone_dir: clone),
      }
    end
  end
end
