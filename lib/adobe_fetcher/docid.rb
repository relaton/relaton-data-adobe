# frozen_string_literal: true

require "pubid"
require "pubid/adobe"

module AdobeFetcher
  # Immutable value object representing an Adobe document identifier
  # across its observed forms:
  #
  #   * tech note natural form — "Adobe TN 5014"
  #   * short alias            — "ATN5014" (id field, parseable)
  #   * filename-derived       — "5014.CIDFont_Spec.pdf"
  #   * publication slug       — "adobe-glyph-list", "adobe-japan1-7"
  #   * publication citation   — "Adobe Publication Adobe Glyph List"
  #                               (uses the title from metadata)
  #   * URN                    — "urn:adobe:tech-note:5014"
  #
  # Two flavours of Docid exist:
  #
  #   * typed   — TechNote with a number. URN generation supported via
  #               Pubid::Adobe.
  #   * generic — slug-keyed Publication. URN generation supported via
  #               Pubid::Adobe (different namespace). Carries an
  #               optional +title+ for the human citation form.
  #
  # The object is a thin wrapper over Pubid::Adobe for parse/URN
  # concerns; it owns the data-repo-specific filename, id, and
  # title-based citation rendering.
  class Docid
    attr_reader :code, :typed, :doctype, :slug, :version, :title

    def initialize(code:, typed:, doctype: nil, slug: nil, version: nil,
                   title: nil)
      @code = code
      @typed = typed
      @doctype = doctype
      @slug = slug
      @version = version
      @title = title
      freeze
    end

    # --- Constructors (one per input grammar) ---

    # Builds a Docid for an Adobe Technical Note given its 4-digit number.
    #   from_tech_note_number(5014)  → code "ATN5014"
    #   from_tech_note_number("5014") → code "ATN5014"
    def self.from_tech_note_number(number, slug: nil)
      n = number.to_s
      raise ArgumentError, "Tech note number must be numeric: #{number.inspect}" unless n.match?(/\A\d+\z/)

      new(
        code:    "ATN#{n}",
        typed:   true,
        doctype: "tech-note",
        slug:    slug,
      )
    end

    # Builds a Docid by parsing the filename of a font-tech-notes PDF.
    # Filenames follow `<number>.<Slug>.pdf`.
    #   "5014.CIDFont_Spec.pdf"  → code "ATN5014", slug "CIDFont_Spec"
    #   "5902.AdobePSNameGeneration.pdf" → code "ATN5902", slug "AdobePSNameGeneration"
    def self.from_filename(filename)
      basename = File.basename(filename.to_s)
      m = basename.match(/\A(\d+)\.([^.]+)\.pdf\z/i)
      unless m
        raise ArgumentError,
              "Filename does not match <number>.<Slug>.pdf: #{filename.inspect}"
      end

      from_tech_note_number(m[1], slug: m[2])
    end

    # Builds a Docid for a named publication from its slug.
    #   from_slug("adobe-glyph-list")    → typed false, doctype "publication"
    #   from_slug("adobe-japan1", version: "7")
    #   from_slug("adobe-glyph-list", title: "Adobe Glyph List")
    def self.from_slug(slug, version: nil, title: nil)
      raise ArgumentError, "Slug must be present" if slug.to_s.strip.empty?

      new(
        code:    slug.to_s,
        typed:   false,
        doctype: "publication",
        slug:    slug.to_s,
        version: version&.to_s,
        title:   title,
      )
    end

    # Builds a Docid by delegating to Pubid::Adobe for parsing. The
    # returned Docid carries the canonical code (number-prefixed for
    # TechNotes, slug for Publications). The title-form citation
    # ("Adobe Publication Adobe Glyph List") is NOT round-trippable via
    # pubid — the parser only accepts the slug form. Use +from_slug+
    # with +title:+ if you need to attach a title.
    def self.from_string(str)
      id = Pubid::Adobe.parse(str)
      case id
      when Pubid::Adobe::Identifiers::TechNote
        from_tech_note_number(id.number, slug: id.slug)
      when Pubid::Adobe::Identifiers::Publication
        from_slug(id.slug, version: id.version)
      else
        raise ArgumentError, "Unrecognized Pubid::Adobe class: #{id.class}"
      end
    end

    # --- Derived forms ---

    # The docidentifier.content string for relaton — the human-readable
    # citation form. For TechNotes, delegates to Pubid::Adobe
    # ("Adobe TN <number>"). For Publications, uses the title from
    # metadata when available ("Adobe Publication <title>"), falling
    # back to the slug-based Pubid rendering.
    def to_s
      return pubid.to_s if typed
      return "Adobe Publication #{title}" if title

      pubid.to_s
    end

    # The relaton `id` field — the canonical parseable identifier.
    # Uses the short code (ATN<number> or <slug>) plus optional
    # `-<version>` for versioned publications. Always parseable by
    # Pubid::Adobe, so the Indexer can build index-v2 from it directly.
    def id
      bits = [code]
      bits << version if version
      bits.join("-")
    end

    # Filename-safe stem for the data/<stem>.yaml path.
    def filename_stem
      id.downcase.tr(" ", "_").gsub("/", "-").gsub(/[^a-z0-9_.-]/, "")
    end

    # URN, delegated to Pubid::Adobe. Always present (both TechNote and
    # Publication emit URNs).
    def urn
      pubid.to_urn
    end

    # The numeric portion of a TechNote code, or nil for Publications.
    def tech_note_number
      return nil unless typed

      code[/\AATN(\d+)\z/, 1]
    end

    # --- Mutators (return new instances; objects are frozen) ---

    def with_title(new_title)
      self.class.new(
        code: code, typed: typed, doctype: doctype, slug: slug,
        version: version, title: new_title,
      )
    end

    # --- Equality ---

    def ==(other)
      other.is_a?(Docid) &&
        other.code == code &&
        other.typed == typed &&
        other.doctype == doctype &&
        other.slug == slug &&
        other.version == version &&
        other.title == title
    end
    alias eql? ==

    def hash
      [code, typed, doctype, slug, version, title].hash
    end

    # --- Pubid bridge ---

    # Builds the equivalent Pubid::Adobe identifier.
    def pubid
      if typed
        Pubid::Adobe::Identifiers::TechNote.new(number: tech_note_number, slug: slug)
      else
        Pubid::Adobe::Identifiers::Publication.new(slug: code, version: version)
      end
    end
  end
end
