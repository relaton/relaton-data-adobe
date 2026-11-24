# frozen_string_literal: true

require "spec_helper"

# Data-integrity check over the committed dataset: every record's primary
# docidentifier is the canonical Pubid::Adobe form, so relaton can parse
# it back to a pubid (cache key, api.relaton.org match, citation).
RSpec.describe "data/*.yaml" do
  data_glob = File.expand_path("../data/*.yaml", __dir__)

  it "is not empty" do
    expect(Dir[data_glob]).not_to be_empty
  end

  Dir[data_glob].each do |file|
    it "#{File.basename(file)} has the canonical primary docidentifier of its id" do
      item = Relaton::Adobe::Item.from_yaml(File.read(file, encoding: "UTF-8"))
      primary = item.docidentifier.find(&:primary)

      expect(primary).not_to be_nil
      expect(primary.content).to eq(Pubid::Adobe.parse(item.id).to_s)
      expect(Pubid::Adobe.parse(primary.content).to_s).to eq(primary.content)
    end
  end
end
