# frozen_string_literal: true

module AdobeFetcher
  # Value object that produces a relaton-compatible +source+ hash with
  # the correct +type+ for the kind of location it represents. Three
  # constructors remove the "local path tagged as website" class of bug.
  class Source
    def self.url(url)
      { "type" => "website", "content" => url }
    end

    # A path on the AdobeTypeTools GitHub repo — resolves against
    # AdobeFetcher::BASE_URL. If the input is already an HTTP(S) URL,
    # it's returned as-is via .url.
    def self.adobe(path)
      return url(path) if path.to_s.start_with?("http")

      base = AdobeFetcher::BASE_URL.chomp("/")
      path = path.to_s.start_with?("/") ? path.to_s : "/#{path}"
      url("#{base}#{path}")
    end

    # The landing page for an entry — distinct from the bytes URL so
    # consumers can tell "where humans read about this" from "where the
    # PDF comes from". Tagged as `website` (same relaton type) but
    # routed through a dedicated constructor so the intent is explicit
    # at the call site.
    def self.webpage(url)
      { "type" => "website", "content" => url }
    end

    def self.local(path)
      { "type" => "file", "content" => path }
    end
  end
end
