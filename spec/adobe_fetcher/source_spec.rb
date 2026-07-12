# frozen_string_literal: true

require "spec_helper"

RSpec.describe AdobeFetcher::Source do
  describe ".url" do
    it "returns a website-typed source hash" do
      expect(described_class.url("https://example.com/foo"))
        .to eq({ "type" => "website", "content" => "https://example.com/foo" })
    end
  end

  describe ".adobe" do
    it "resolves a path against the Adobe BASE_URL" do
      expect(described_class.adobe("/foo")["content"])
        .to eq("#{AdobeFetcher::BASE_URL}/foo")
    end

    it "returns the URL as-is when given an http URL" do
      expect(described_class.adobe("https://other.example.com/x"))
        .to eq({ "type" => "website", "content" => "https://other.example.com/x" })
    end

    it "prepends a slash when missing" do
      expect(described_class.adobe("foo")["content"])
        .to eq("#{AdobeFetcher::BASE_URL}/foo")
    end
  end

  describe ".webpage" do
    it "returns a website-typed source hash" do
      expect(described_class.webpage("https://example.com"))
        .to eq({ "type" => "website", "content" => "https://example.com" })
    end
  end

  describe ".local" do
    it "returns a file-typed source hash" do
      expect(described_class.local("/tmp/foo.pdf"))
        .to eq({ "type" => "file", "content" => "/tmp/foo.pdf" })
    end
  end
end
