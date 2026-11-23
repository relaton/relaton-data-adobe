# frozen_string_literal: true

source "https://rubygems.org"

# Pin psych: 5.3.0 silently breaks the YAML round-trip that check_data.rb
# depends on (key ordering / quoting differences). Documented in
# relaton-data-oiml Gemfile.
gem "psych", "~> 5.2.6"

# relaton is the single combined v3 gem. The Adobe flavor lives inside
# it at lib/relaton/adobe/ (merged to main via relaton/relaton#56).
gem "relaton",
    git: "https://github.com/relaton/relaton.git",
    branch: "main"

# pubid v2 (with Adobe support) parses primary docids into structured
# identifiers for the pubid_class-based index-v2.yaml. The Adobe flavor
# (metanorma/pubid#107) is merged, so track pubid main.
gem "pubid",
    git: "https://github.com/metanorma/pubid.git",
    branch: "main"

gem "thor",              "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false   # String#squish for abstract cleaning
# relaton main depends on rubyzip ~> 3.7 (relaton#264); match it —
# crawler.rb compresses index*.yaml → index*.zip. The old ~> 2.3 pin
# conflicts with relaton main and broke the daily crawl (2026-11).
gem "rubyzip",           "~> 3.7"

group :development, :test do
  gem "rspec", "~> 3.13"
  gem "webmock"
end
