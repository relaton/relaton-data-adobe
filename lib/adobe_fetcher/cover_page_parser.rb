# frozen_string_literal: true

module AdobeFetcher
  # Parses the cover-page text of an Adobe tech-note PDF into structured
  # fields.
  #
  # Adobe tech-note covers vary in layout but reliably contain:
  #
  #   Adobe Technical Note #5014
  #   Adobe CMap and CID Font Files Specification
  #   Version 1.0
  #   11 June 1993
  #
  # The parser scans for *field patterns* (regex per field) rather than
  # positional lines, so a different layout doesn't break it.
  class CoverPageParser
    Result = Struct.new(
      :number,         # "5014"
      :title,          # "Adobe CMap and CID Font Files Specification"
      :date,           # Date object, or nil
      :edition,        # "1.0"
      :urn,            # "urn:adobe:tech-note:5014"
      keyword_init: true,
    )

    class MissingCoverFields < StandardError; end

    MONTHS = %w[
      January February March April May June July
      August September October November December
    ].freeze

    DATE_MONTH_YEAR   = /\A(#{MONTHS.join("|")})\s+(\d{4})\z/i
    DATE_DAY_MONTH_YR = /\A(\d{1,2})\s+(#{MONTHS.join("|")})\s+(\d{4})\z/i
    DATE_MONTH_DAY_YR = /\A(#{MONTHS.join("|")})\s+(\d{1,2}),?\s+(\d{4})\z/i

    # Lines that mark the tech-note number. Single alternation regex so
    # the capture-group index is stable regardless of which form
    # matched. Canonical "Adobe TN" first, then legacy "Adobe Technical
    # Note", then short alias "ATN".
    NUMBER_LINE = /\A(?:Adobe\s+TN|Adobe\s+Technical\s+Note\s+#?|ATN)\s*-?\s*(\d+)\z/i.freeze

    VERSION_LINE = /\A(?:Version|Edition)\s+(\d+(?:\.\d+)*)\z/i
    URN_LINE     = /\Aurn:adobe:/i

    def self.parse(text)
      new(text).parse
    end

    def initialize(text)
      @text = text.to_s
      @lines = @text.lines.map(&:strip).reject(&:empty?)
    end

    def parse
      raise MissingCoverFields, "no text to parse" if @lines.empty?

      Result.new(
        number:  number,
        title:   title,
        date:    date,
        edition: edition,
        urn:     urn,
      )
    end

    private

    def number
      @lines.each do |line|
        m = line.match(NUMBER_LINE)
        return m[1] if m
      end
      nil
    end

    # The title is the first non-empty line that isn't the tech-note
    # marker, a version/edition line, a date, or a URN.
    def title
      @lines.each do |line|
        next if line.match?(NUMBER_LINE)
        next if line.match?(VERSION_LINE)
        next if date_line?(line)
        next if line.match?(URN_LINE)
        next if line.match?(/\AInformation\s+About\z/i) # common subtitle marker

        return line
      end
      nil
    end

    def edition
      @lines.each do |line|
        m = line.match(VERSION_LINE)
        return m[1] if m
      end
      nil
    end

    def date
      @lines.each do |line|
        return parse_date(line) if date_line?(line)
      end
      nil
    end

    def date_line?(line)
      line.match?(DATE_MONTH_YEAR) ||
        line.match?(DATE_DAY_MONTH_YR) ||
        line.match?(DATE_MONTH_DAY_YR)
    end

    def parse_date(line)
      if (m = line.match(DATE_DAY_MONTH_YR))
        Date.new(m[3].to_i, month_index(m[2]), m[1].to_i)
      elsif (m = line.match(DATE_MONTH_DAY_YR))
        Date.new(m[3].to_i, month_index(m[1]), m[2].to_i)
      elsif (m = line.match(DATE_MONTH_YEAR))
        Date.new(m[2].to_i, month_index(m[1]), 1)
      end
    end

    def month_index(name)
      MONTHS.index { |m| m.casecmp(name).zero? }&.+(1) ||
        (raise ArgumentError, "Unknown month: #{name.inspect}")
    end

    def urn
      @lines.each do |line|
        return line.strip if line.match?(URN_LINE)
      end
      nil
    end
  end
end
