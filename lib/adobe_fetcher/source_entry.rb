# frozen_string_literal: true

module AdobeFetcher
  # Common base type for every entry yielded by a Source. Each entry
  # knows how to build its own Docid (polymorphism, not type-dispatch
  # in the orchestrator) and exposes the optional location fields
  # (filename, absolute_path, web_url, bytes_url) with nil defaults.
  #
  # For Publications, the optional +title+ rides along so the
  # resulting Docid can render "Adobe Publication <title>" citations.
  class SourceEntry
    attr_reader :number, :slug, :version, :title, :filename,
                :absolute_path, :web_url, :bytes_url

    # rubocop:disable Metrics/ParameterLists
    def initialize(number: nil, slug: nil, version: nil, title: nil,
                   filename: nil, absolute_path: nil, web_url: nil,
                   bytes_url: nil)
      @number        = number
      @slug          = slug
      @version       = version
      @title         = title
      @filename      = filename
      @absolute_path = absolute_path
      @web_url       = web_url
      @bytes_url     = bytes_url
    end
    # rubocop:enable Metrics/ParameterLists

    # Builds the Docid for this entry. The dispatch is on data shape
    # (number present vs slug present), not on entry class — the
    # invariant is that a tech-note entry always has `number` and a
    # publication entry always has `slug`. The +title+ is forwarded
    # onto Publication Docids so #to_s can render the citation form.
    def to_docid
      if number
        AdobeFetcher::Docid.from_tech_note_number(number, slug: slug)
      elsif slug
        AdobeFetcher::Docid.from_slug(slug, version: version, title: title)
      else
        raise ArgumentError,
              "Entry has neither number nor slug: #{inspect}"
      end
    end
  end
end
