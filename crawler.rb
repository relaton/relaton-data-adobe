#!/usr/bin/env ruby
# frozen_string_literal: true

# Crawler entry point (the relaton/support workflow runs `bundle exec ruby
# crawler.rb`, then commits the index*.yaml / index*.zip it produces).
#
# Generates index-v1 (string docid) and index-v2 (structured Pubid::Adobe)
# in a single pass over data/*.yaml, then compresses each into a sibling
# index*.zip.

require "bundler/setup"
$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "relaton/index"
require "relaton/bib"
require "adobe_fetcher"

INDEX_V1 = "index-v1.yaml"
INDEX_V2 = "index-v2.yaml"

AdobeFetcher::Indexer.build(
  data_dir: "data",
  index_file: INDEX_V1,
  index_v2_file: INDEX_V2,
)
AdobeFetcher::Indexer.zip(INDEX_V1, INDEX_V2)
