# frozen_string_literal: true

source "https://rubygems.org"

# Pin psych: 5.3.0 silently breaks the YAML round-trip that check_data.rb
# depends on (key ordering / quoting differences). Documented in
# relaton-data-oiml Gemfile.
gem "psych", "~> 5.2.6"

# relaton is the single combined v3 gem. The Adobe flavor lives inside
# it at lib/relaton/adobe/. Path: during development; flip to
#   git: "https://github.com/relaton/relaton.git", branch: "main"
# once the Adobe flavor PR (relaton/relaton#NN) merges.
gem "relaton", path: "../relaton"

# pubid v2 (with Adobe support) parses primary docids into structured
# identifiers for the pubid_class-based index-v2.yaml. Tracks the
# rt-new-lutaml-model branch until pubid v2 is released.
gem "pubid", path: "../../mn/pubid"

gem "thor",              "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false   # String#squish for abstract cleaning

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "webmock"
end
