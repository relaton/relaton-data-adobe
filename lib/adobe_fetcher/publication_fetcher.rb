# frozen_string_literal: true

require "date"
require "fileutils"
require "open3"

module AdobeFetcher
  # Orchestrates the full pipeline:
  #
  #   Sources::Base#each_entry
  #       │ yields Entry (number, slug, paths)
  #       ▼
  #   PdfDownloader#fetch            (for URL-based sources)
  #       │ returns local path
  #       ▼
  #   text = pdftotext -layout -l 1  (preferred)
  #   text = CoverPageOcr#ocr_first_page  (fallback for scans)
  #       │
  #       ▼
  #   CoverPageParser.parse(text)    → Result Struct
  #       │
  #       ▼
  #   build hash via Relaton::Adobe::Item.from_hash
  #       │
  #       ▼
  #   YamlStore.write(filename_stem, hash)
  #
  # Each stage is independent and testable; the fetcher sequences them.
  class PublicationFetcher
    attr_reader :data_dir, :yaml_store, :sources,
                :pdf_downloader, :cover_page_ocr

    def initialize(data_dir:, yaml_store:, sources:,
                   pdf_downloader: nil, cover_page_ocr: nil)
      @data_dir = data_dir
      @yaml_store = yaml_store
      @sources = Array(sources)
      @pdf_downloader = pdf_downloader
      @cover_page_ocr = cover_page_ocr
    end

    def run
      FileUtils.mkdir_p(@data_dir)

      @sources.each do |source|
        emit_from_source(source)
      end
    end

    private

    def emit_from_source(source)
      source.each_entry do |entry|
        emit_entry(entry)
      rescue StandardError => e
        warn "  ERROR emitting #{entry&.filename || entry.inspect}: #{e.message}"
      end
    end

    def emit_entry(entry)
      docid = entry.to_docid
      cover = cover_for(entry, name: docid.filename_stem)

      hash = build_hash(entry, docid, cover)
      yaml_store.write(docid.filename_stem, hash)
    end

    def cover_for(entry, name:)
      pdf_path = pdf_path_for(entry, name: name)
      return nil unless pdf_path

      text = extract_first_page_text(pdf_path)
      text = ocr_first_page(pdf_path, name: name) if (text.nil? || text.strip.empty?) && @cover_page_ocr
      return nil unless text && !text.strip.empty?

      AdobeFetcher::CoverPageParser.parse(text)
    rescue StandardError => e
      warn "    cover page parse: #{e.message}"
      nil
    end

    # For local-filesystem sources (e.g. cloned git repo), the entry
    # already has the local path. For URL-based sources, download via
    # PdfDownloader. SourceEntry exposes #absolute_path and #bytes_url
    # with nil defaults so no type dispatch is needed here.
    def pdf_path_for(entry, name:)
      return entry.absolute_path if entry.absolute_path && File.exist?(entry.absolute_path)
      return nil unless @pdf_downloader && entry.bytes_url

      @pdf_downloader.fetch(entry.bytes_url, name: name)
    end

    def extract_first_page_text(pdf_path)
      out, status = Open3.capture2("pdftotext", "-layout", "-l", "1", pdf_path, "-")
      return nil unless status.success? && !out.empty?

      out
    rescue StandardError
      nil
    end

    def ocr_first_page(pdf_path, name:)
      return nil unless @cover_page_ocr

      @cover_page_ocr.ocr_first_page(pdf_path, name: name)
    end

    def build_hash(entry, docid, cover)
      title_text = cover&.title || entry.title || title_case_slug(entry.slug) || docid.to_s
      date = cover&.date
      edition = cover&.edition

      hash = {
        "id" => docid.id,
        "type" => "standard",
        "title" => [{
          "language" => "eng",
          "content" => title_text,
          "type" => "main",
        }],
        "docidentifier" => [{
          "content" => docid.to_s,
          "type" => "ADOBE",
          "primary" => true,
        }],
        "docnumber" => docnumber_for(docid),
        "contributor" => [AdobeFetcher.adobe_publisher_contributor],
        "language" => ["eng"],
        "script" => ["Latn"],
        "status" => { "stage" => { "content" => "in-force" } },
        "ext" => ext_block(entry, docid, cover),
      }
      apply_source!(hash, entry)
      apply_dates!(hash, date)
      apply_edition!(hash, edition)
      apply_copyright!(hash, date)
      hash
    end

    def docnumber_for(docid)
      return docid.tech_note_number if docid.tech_note_number

      docid.code
    end

    def title_case_slug(slug)
      return nil unless slug

      slug.to_s
          .tr("_", " ")
          .gsub(/\b([a-z])/) { Regexp.last_match(1).upcase }
    end

    def ext_block(entry, docid, cover)
      ext = {
        "doctype" => { "content" => docid.doctype },
        "flavor" => "adobe",
      }
      urn = cover&.urn || docid.urn
      ext["urn"] = urn if urn && !urn.empty?
      ext["webpage"] = entry.web_url if entry.web_url
      ext["tech_note_number"] = docid.tech_note_number if docid.tech_note_number
      ext["source_repo_path"] = "pdfs/#{entry.filename}" if entry.filename
      ext["publication_slug"] = docid.slug if docid.slug && !docid.typed
      ext
    end

    def apply_source!(hash, entry)
      return unless entry.bytes_url

      hash["source"] = [AdobeFetcher::Source.url(entry.bytes_url)]
    end

    def apply_dates!(hash, date)
      return unless date

      hash["date"] = [{ "type" => "published", "from" => date.iso8601 }]
      hash["version"] = [{ "content" => date.iso8601 }]
    end

    def apply_edition!(hash, edition)
      return unless edition

      # Relaton::Bib::Edition is a singular model (number/content), not
      # a collection — an array here fails Item.from_yaml.
      hash["edition"] = { "content" => edition }
    end

    def apply_copyright!(hash, date)
      return unless date

      hash["copyright"] = [{
        "from" => date.year.to_s,
        "owner" => [{ "organization" => AdobeFetcher.adobe_org_hash }],
      }]
    end
  end
end
