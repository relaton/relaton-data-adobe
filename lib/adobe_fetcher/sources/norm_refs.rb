# frozen_string_literal: true

module AdobeFetcher
  module Sources
    # The Adobe technical notes and named specifications cited normatively
    # by ISO 32000-2, whose canonical copies live on pdfa.org
    # (/norm-refs/ — WAF-guarded against automated fetches, so these
    # entries are curated rather than crawled) and on the standards
    # bodies' and Adobe's own repositories.
    #
    # Every record's title and date are the citation metadata of record —
    # taken from the normative-references section of the ISO 32000-2
    # (pdf-association/spec-pdf-core) — so the records are complete
    # without a cover-page download. The links point at the canonical
    # copy of each document.
    #
    # Verified against the citing documents and the live sources,
    # 2026-11-23.
    class NormRefs < Base
      NORM_REFS_PREFIX = "https://www.pdfa.org/norm-refs".freeze
      AGLFN_URL = "https://github.com/adobe-type-tools/agl-aglfn".freeze
      AGLFN_RAW =
        "https://raw.githubusercontent.com/adobe-type-tools/agl-aglfn/main".freeze
      CMAP_URL = "https://github.com/adobe-type-tools/cmap-resources".freeze

      # The notes: number, slug (the norm-refs filename stem where one
      # exists), title, date, canonical link.
      TECH_NOTES = [
        {
          number: "5001", slug: "DSC_Spec",
          title: "PostScript Language Document Structuring Conventions " \
                 "Specification, Version 3.0",
          date: "1992-09",
          bytes_url: "#{NORM_REFS_PREFIX}/5001.DSC_Spec.pdf",
        },
        {
          number: "5044",
          title: "Color Separation Conventions for PostScript Language " \
                 "Programs",
          date: "1996-05",
          bytes_url: "https://printtechnologies.org/standards/files/" \
                     "technote5044.pdf",
        },
        {
          number: "5116", slug: "DCT_Filter",
          title: "Supporting the DCT Filters in PostScript Level 2",
          date: "1992-11",
          bytes_url: "#{NORM_REFS_PREFIX}/5116.DCT_Filter.pdf",
        },
        {
          number: "5411", slug: "ToUnicode",
          title: "ToUnicode Mapping File Tutorial",
          date: "2003-05-29",
          bytes_url: "#{NORM_REFS_PREFIX}/5411.ToUnicode.pdf",
        },
        {
          number: "5620", slug: "PortableJobTicket",
          title: "Portable Job Ticket Format, Version 1.1",
          date: "1999-04",
          bytes_url: "#{NORM_REFS_PREFIX}/5620.PortableJobTicket.pdf",
        },
        {
          number: "5660", slug: "OPI_2_0",
          title: "Open Prepress Interface (OPI) Specification, Version 2.0",
          date: "2000-01",
          bytes_url: "#{NORM_REFS_PREFIX}/5660_OPI_2_0.pdf",
        },
      ].freeze

      # The named specifications: slug, version, title, date, link.
      PUBLICATIONS = [
        {
          slug: "postscript-language-reference", version: "3.0",
          title: "PostScript Language Reference, Third Edition",
          date: "1999-02",
          bytes_url: "#{NORM_REFS_PREFIX}/PLRM.pdf",
        },
        {
          slug: "pdf-signature-build-dictionary", version: "1.4",
          title: "PDF Signature Build Dictionary Specification",
          date: "2008-03",
          bytes_url: "#{NORM_REFS_PREFIX}/SigBuildDict.pdf",
        },
        {
          slug: "tiff", version: "6.0",
          title: "TIFF, Revision 6.0",
          date: "1992-06",
          bytes_url: "#{NORM_REFS_PREFIX}/TIFF6.pdf",
        },
        {
          slug: "xfa", version: "3.3",
          title: "XML Forms Architecture (XFA) Specification",
          date: "2012-01",
          bytes_url: "#{NORM_REFS_PREFIX}/XFA-3_3.pdf",
        },
        {
          slug: "adobe-glyph-list",
          title: "Adobe Glyph List",
          bytes_url: "#{AGLFN_RAW}/aglfn.txt",
        },
        {
          slug: "adobe-glyph-list-for-new-fonts",
          title: "Adobe Glyph List for New Fonts",
          bytes_url: "#{AGLFN_RAW}/AGLFN.txt",
        },
        {
          slug: "adobe-japan1", version: "7",
          title: "Adobe-Japan1-7 Character Collection for CID-Keyed Fonts",
          bytes_url: "#{CMAP_URL}/raw/main/other-cmaps/adobe-japan1-7.cmap",
        },
        {
          slug: "adobe-gb1", version: "5",
          title: "Adobe-GB1-5 Character Collection for CID-Keyed Fonts",
          bytes_url: "#{CMAP_URL}/raw/main/other-cmaps/adobe-gb1-5.cmap",
        },
      ].freeze

      def each_entry
        return enum_for(:each_entry) unless block_given?

        TECH_NOTES.each do |t|
          url = t[:bytes_url]
          yield SourceEntry.new(
            number: t[:number], slug: t[:slug], title: t[:title],
            date: t[:date],
            web_url: url, bytes_url: url,
          )
        end
        PUBLICATIONS.each do |p|
          url = p[:bytes_url]
          yield SourceEntry.new(
            slug: p[:slug], version: p[:version], title: p[:title],
            date: p[:date],
            web_url: url, bytes_url: url,
          )
        end
      end
    end
  end
end
