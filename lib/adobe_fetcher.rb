# frozen_string_literal: true

require "relaton/bib"
require "relaton/adobe"

# AdobeFetcher scrapes Adobe publication sources (the font-tech-notes
# git repo, the Adobe Glyph List repo, cmap-resources, etc.) into
# Relaton YAML files under data/.
module AdobeFetcher
  # Landing-page URL for the font-tech-notes repository — also the
  # canonical webpage attached to each tech note's relaton record.
  BASE_URL = "https://github.com/adobe-type-tools/font-tech-notes".freeze

  TECH_NOTES_REPO_URL =
    "https://github.com/adobe-type-tools/font-tech-notes.git".freeze

  # Web-facing URL prefix for the per-file landing page on GitHub. The
  # fetcher appends `pdfs/<filename>` to this.
  TECH_NOTES_WEB_PREFIX =
    "https://github.com/adobe-type-tools/font-tech-notes/blob/main".freeze

  ADOBE_NAME    = "Adobe Systems Incorporated".freeze
  ADOBE_ABBR    = "Adobe".freeze

  # Mapping from doctype key to its descriptive title and identifier
  # short code. New doctypes are added here; nothing else in the code
  # base branches on doctype (OCP).
  DOCTYPES = {
    "tech-note"   => { title: "Technical Note",  short: "ATN" },
    "publication" => { title: "Publication",     short: nil  },
  }.freeze

  def self.adobe_org_hash
    {
      "name" => [{ "content" => ADOBE_NAME }],
      "abbreviation" => { "content" => ADOBE_ABBR },
    }
  end

  def self.adobe_publisher_contributor
    {
      "role" => [{ "type" => "publisher" }],
      "organization" => adobe_org_hash,
    }
  end

  # autoload entries — defined here so `require "adobe_fetcher"` makes
  # every submodule available lazily. No `require_relative` in lib/.
  autoload :Docid,              "adobe_fetcher/docid"
  autoload :Source,             "adobe_fetcher/source"
  autoload :SourceEntry,        "adobe_fetcher/source_entry"
  autoload :Http,               "adobe_fetcher/http"
  autoload :YamlStore,          "adobe_fetcher/yaml_store"
  autoload :PdfDownloader,      "adobe_fetcher/pdf_downloader"
  autoload :CoverPageOcr,       "adobe_fetcher/cover_page_ocr"
  autoload :CoverPageParser,    "adobe_fetcher/cover_page_parser"
  autoload :PublicationFetcher, "adobe_fetcher/publication_fetcher"
  autoload :Indexer,            "adobe_fetcher/indexer"
  autoload :Scrape,             "adobe_fetcher/scrape"

  # Sources namespace — each source lives under AdobeFetcher::Sources.
  module Sources
    autoload :Base,             "adobe_fetcher/sources/base"
    autoload :TechNotes,        "adobe_fetcher/sources/tech_notes"
  end
end
