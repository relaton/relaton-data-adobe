# frozen_string_literal: true

require "erb"
require "fileutils"

module AdobeFetcher
  module Sources
    # Adobe font technical notes, scraped from the
    # adobe-type-tools/font-tech-notes git repository. Each PDF under
    # pdfs/ is one tech note; filenames follow <number>.<Slug>.pdf
    # (see AdobeFetcher::Docid.from_filename).
    class TechNotes < Base
      REPO_URL = "https://github.com/adobe-type-tools/font-tech-notes.git".freeze
      WEB_PREFIX = "https://github.com/adobe-type-tools/font-tech-notes/blob/main".freeze
      DEFAULT_CLONE_DIR = File.join(Dir.tmpdir, "adobe-font-tech-notes").freeze

      FILENAME_PATTERN = /\A(?:TN)?(\d+)\.([^.]+)\.pdf\z/i.freeze
      # Unnumbered notes (no leading digits) still get a record, as a
      # slug-keyed publication rather than a tech note.
      UNNUMBERED_PATTERN = /\A([^.]+)\.pdf\z/i.freeze

      def initialize(clone_dir: DEFAULT_CLONE_DIR)
        @clone_dir = clone_dir
      end

      # Yield one SourceEntry per tech-note PDF. Numbered files follow
      # <number>.<Slug>.pdf; unnumbered ones become slug-keyed
      # publications. Files matching neither shape are warned about and
      # skipped rather than raising, so one oddly named file cannot
      # abort a whole crawl.
      #
      # @yieldparam [AdobeFetcher::SourceEntry]
      # @return [Enumerator] when called without a block
      def each_entry
        return enum_for(:each_entry) unless block_given?

        ensure_clone
        pdfs = File.join(@clone_dir, "pdfs")
        Dir[File.join(pdfs, "*.pdf")].sort.each do |path|
          filename = File.basename(path)

          id_args =
            if (m = filename.match(FILENAME_PATTERN))
              { number: m[1], slug: m[2] }
            elsif (u = filename.match(UNNUMBERED_PATTERN))
              { slug: publication_slug(u[1]) }
            end

          unless id_args
            warn "Skipping unrecognized filename: #{filename}"
            next
          end

          yield SourceEntry.new(
            **id_args,
            filename: filename,
            absolute_path: path,
            web_url: "#{WEB_PREFIX}/pdfs/#{ERB::Util.url_encode(filename)}",
            bytes_url: "#{WEB_PREFIX.sub('blob', 'raw')}/pdfs/#{ERB::Util.url_encode(filename)}",
          )
        end
      end

      private

      # Kebab-case, lowercase — the shape Pubid::Adobe publications use
      # ("adobe-glyph-list"), so index-v2 round-trips the id.
      def publication_slug(stem)
        stem.gsub(/([a-z\d])([A-Z])/, '\1-\2').tr("_", "-").downcase
      end

      private

      # Reuse an existing clone (a stale one is refreshed by the
      # git pull); clone shallow otherwise.
      def ensure_clone
        if Dir.exist?(File.join(@clone_dir, ".git"))
          system("git -C #{@clone_dir} pull --ff-only", exception: true)
        else
          FileUtils.mkdir_p(File.dirname(@clone_dir))
          system(
            "git clone --depth 1 #{REPO_URL} #{@clone_dir}",
            exception: true,
          )
        end
      end
    end
  end
end
