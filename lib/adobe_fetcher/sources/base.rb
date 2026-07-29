# frozen_string_literal: true

module AdobeFetcher
  module Sources
    # Abstract base for every source. A source enumerates the upstream
    # material (a cloned git repo, a downloaded catalogue, …) and yields
    # one AdobeFetcher::SourceEntry per publication. The orchestrator
    # (PublicationFetcher) depends only on this contract, so adding a new
    # source is adding one Sources::<Name> < Sources::Base subclass.
    class Base
      # Yield each AdobeFetcher::SourceEntry. Concrete sources override
      # this; called with no block it should return an Enumerator.
      #
      # @yieldparam [AdobeFetcher::SourceEntry]
      # @return [Enumerator] when called without a block
      def each_entry
        raise NotImplementedError, "#{self.class}#each_entry"
      end
    end
  end
end
