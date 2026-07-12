# frozen_string_literal: true

source "https://rubygems.org"

# Pin psych: 5.3.0 silently breaks the YAML round-trip that check_data.rb
# depends on (key ordering / quoting differences). Documented in
# relaton-data-oiml Gemfile.
gem "psych", "~> 5.2.6"

# relaton is the single combined v3 gem. The Adobe flavor lives inside
# it at lib/relaton/adobe/. Pinned to the feat/adobe-flavor branch in
# relaton/relaton#56 until that PR merges, then flip back to main.
gem "relaton",
    git: "https://github.com/relaton/relaton.git",
    branch: "feat/adobe-flavor"

# pubid v2 (with Adobe support) parses primary docids into structured
# identifiers for the pubid_class-based index-v2.yaml. Pinned to the
# feat/adobe-flavor branch in metanorma/pubid#107 until that PR merges,
# then flip back to rt-new-lutaml-model or main.
gem "pubid",
    git: "https://github.com/metanorma/pubid.git",
    branch: "feat/adobe-flavor"

gem "thor",              "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false   # String#squish for abstract cleaning

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "webmock"
end
