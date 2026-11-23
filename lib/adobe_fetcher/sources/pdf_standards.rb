# frozen_string_literal: true

require "json"

module AdobeFetcher
  module Sources
    # The PDF Reference editions, hosted by Adobe in the
    # dc-acrobat-sdk-docs git repository under docs/pdfstandards/.
    # Filenames: pdfreference<version>.pdf (1.0 → 1.7).
    #
    # PDF32000_2008.pdf sits in the same tree but is NOT fetched here:
    # it is the ISO 32000-1:2008 text — an ISO-authored document that
    # Adobe hosts a courtesy copy of — and belongs to the ISO dataset's
    # domain, not this one.
    #
    # The entries carry the well-established publication years of each
    # edition; a cover-page fetch (`--pdfs`) refines them to full dates.
    class PdfStandards < Base
      TREES_API =
        "https://api.github.com/repos/adobe/dc-acrobat-sdk-docs/git/trees/master" \
        "?recursive=1".freeze
      WEB_PREFIX =
        "https://github.com/adobe/dc-acrobat-sdk-docs/blob/master".freeze
      RAW_PREFIX =
        "https://raw.githubusercontent.com/adobe/dc-acrobat-sdk-docs/master".freeze
      DIR = "docs/pdfstandards".freeze

      FILENAME_PATTERN = /\Apdfreference([0-9]+\.[0-9]+)(?:_v\d+|old)?\.pdf\z/i.freeze
      # The ISO 32000-1 text; ISO-authored — see the class comment.
      EXCLUDED = /\A(?:pdf32000|PDF32000_2008)\.pdf\z/i.freeze

      # The publication years of the reference editions. Well-established
      # print history; the cover-page fetch refines to full dates.
      EDITION_YEARS = {
        "1.0" => "1993", "1.2" => "1996", "1.3" => "2000", "1.4" => "2001",
        "1.5" => "2003", "1.6" => "2004", "1.7" => "2006",
      }.freeze

      TITLE = "PDF Reference: Adobe Portable Document Format".freeze

      def initialize(http: AdobeFetcher::Http.backend || AdobeFetcher::Http::NetHttp)
        @http = http
      end

      # @yieldparam [AdobeFetcher::SourceEntry]
      # @return [Enumerator] when called without a block
      def each_entry
        return enum_for(:each_entry) unless block_given?

        listing.each do |name|
          m = FILENAME_PATTERN.match(name)
          unless m
            warn "Skipping unrecognized pdfstandards file: #{name}"
            next
          end
          version = m[1]

          yield SourceEntry.new(
            slug: "pdf-reference",
            version: version,
            title: "#{TITLE}, Version #{version}",
            source_repo_path: "#{DIR}/#{name}",
            web_url: "#{WEB_PREFIX}/#{DIR}/#{name}",
            bytes_url: "#{RAW_PREFIX}/#{DIR}/#{name}",
            date: EDITION_YEARS[version],
          )
        end
      end

      private

      # One trees-API call lists the directory; unauthenticated is fine
      # at one request per crawl.
      def listing
        body = @http.get(TREES_API, headers: { "Accept" => "application/json" })
        tree = JSON.parse(body).fetch("tree", [])
        tree.select { |t| t["path"].start_with?("#{DIR}/") && t["path"].end_with?(".pdf") }
            .map { |t| t["path"].delete_prefix("#{DIR}/") }
            .reject { |name| name.match?(EXCLUDED) }
            .sort
      rescue JSON::ParserError, KeyError => e
        warn "pdfstandards listing failed: #{e.message}"
        []
      end
    end
  end
end
