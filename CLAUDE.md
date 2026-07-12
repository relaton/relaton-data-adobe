# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Bibliographic dataset of Adobe publications, stored as Relaton YAML under
`data/`. Initial scope is the **Adobe Type Tools font tech notes**
(sourced from `github.com/adobe-type-tools/font-tech-notes`), with later
phases adding the broader set of Adobe specifications cited by PDF
Association standards (PostScript Language, Adobe Glyph List, XFA,
Adobe-Japan1/GB1/CNS1/Korea1/KR-9 character collections, etc.).

The scraper lives in this repo (`lib/adobe_fetcher/`); the data is
consumed by the unified `relaton` gem via the `Relaton::Adobe` flavor
that lives inside the gem at `lib/relaton/adobe/`
(PR [relaton/relaton#56](https://github.com/relaton/relaton/pull/56),
tracks issue [relaton/relaton#39](https://github.com/relaton/relaton/issues/39)).

Sibling to `relaton-data-iala` under `/Users/mulgogi/src/relaton/`.
The architecture, file layout, OCR pipeline, and indexing contract
mirror `relaton-data-iala` — read its `CLAUDE.md` and `AGENTS.md` first.

## Adobe identifier model

Adobe publishes two distinct shapes of documents that all need pubids:

### 1. Technical Notes — numbered, typed

Cited as `Adobe TN <number>` (e.g. `Adobe TN 5014`, `Adobe TN 5902`).
The numbers are 4-digit (5xxx series observed: 5004, 5014, 5015, 5116,
5176, 5177, 5620, 5660, 5902). Source filenames follow
`<number>.<Slug>.pdf` (e.g. `5004.AFM_Spec.pdf`, `5176.CFF_.pdf`,
`5902.AdobePSNameGeneration.pdf`).

The Metanorma/PDFA citation style uses `ATN<number>` short anchors
(`[[atn5014,Adobe TN 5014]]`). The pubid canonical form is
`Adobe TN 5014` (human); the URN is `urn:adobe:tech-note:5014`
(machine). Legacy forms (`Adobe Technical Note #5014`, `ATN5014`)
remain parseable for back-compat.

### 2. Named publications — slug-keyed, untyped

Cited as `Adobe Publication <title>` where `<title>` is the
publication's actual title (e.g. `Adobe Publication Adobe Glyph List`).
The Pubid library renders the structural form
`Adobe Publication <slug>` (e.g. `Adobe Publication adobe-glyph-list`);
the data repo's `AdobeFetcher::Docid` overrides `to_s` to use the
title from metadata when available.

Examples drawn from the PDF/A normative-references list:
- Adobe PostScript Language Third Edition (Feb 1999)
- Adobe Glyph List / Adobe Glyph List for New Fonts
- Adobe PDF Signature Build Dictionary Specification v.1.4
- Adobe TIFF Revision 6.0
- Adobe Type 1 Font Format (Addison-Wesley, ISBN)
- XML Forms Architecture (XFA) Specification v.3.3
- Adobe-Japan1-7 / Adobe-GB1-5 / Adobe-CNS1-7 / Adobe-Korea1-2 /
  Adobe-KR-9 / Adobe-Japan2-0 Character Collections for CID-Keyed Fonts

These have no number; they're identified by slug + optional version.
The URN is `urn:adobe:publication:<slug>[:v<version>]`.

### Pubid::Adobe flavor shape

Lives in `mn/pubid/lib/pubid/adobe/`, targets the `rt-new-lutaml-model`
branch (same as IALA). Follows the IALA/OIML/IHO pattern exactly:

```
lib/pubid/adobe.rb            # extend PrefixesSupport, PREFIXES, Registry.register
lib/pubid/adobe/
  identifier.rb               # base < Pubid::Identifier; attributes publisher/number/edition/date/slug
  identifiers/
    base.rb                   # alias back to Identifier
    tech_note.rb              # Adobe TN <number> (canonical); legacy ATN/Adobe Technical Note parseable
    publication.rb            # slug-keyed named specs (Adobe Glyph List, etc.)
  parser.rb                   # Parslet PEG grammar
  builder.rb                  # parse tree → identifier object
  renderer.rb                 # < Pubid::Renderers::Base — human form
  urn_generator.rb            # urn:adobe:<type>:…
  urn_parser.rb               # reverse
```

`PREFIXES = ["Adobe", "ATN"].freeze` plus the joint-publisher tokens
Adobe shares with ISO (e.g. `Adobe/ISO`) declared centrally in
`Pubid::JOINT_PREFIXES`. `Pubid::Adobe.identifier_types` and
`locate_type` follow IALA's exact shape so relaton-index can wire
`index-v2.yaml` with `pubid_class: Pubid::Adobe::Identifier`.

## Relaton::Adobe flavor (inside relaton/relaton unified gem)

The `Relaton::Adobe` flavor lives at
`relaton/relaton:lib/relaton/adobe/` (PR
[relaton/relaton#56](https://github.com/relaton/relaton/pull/56)).
It provides `Relaton::Adobe::Ext < Relaton::Bib::Ext` with typed
attributes for the Adobe-specific metadata the OCR harvests (e.g.
`urn`, `webpage`, `tech_note_number`, `source_repo_path`,
`publication_slug`) — these round-trip natively through YAML and XML,
so `check_data.rb` doesn't need a merge hack.

`Relaton::Adobe::Doctype::TYPES` starts with `%w[tech-note
publication]` and grows as new categories arrive (Adobe SDK specs,
etc.).

`Relaton::Adobe::Processor` registers with `Relaton::Db::Registry`
so `relaton fetch adobe …` works once the dataset ships. Short name
`:relaton_adobe`, prefix `"Adobe"`, defaultprefix `/^(?:Adobe|ATN)/`
— matches `Adobe TN 5014`, `Adobe Publication …`, legacy
`Adobe Technical Note #5014`, and `ATN5014`.

## Source data

Clone `git@github.com:adobe-type-tools/font-tech-notes.git` once; the
PDFs live under `pdfs/<NNNN>.<Slug>.pdf`. The fetcher enumerates that
directory (NOT network-scraped like IALA — there's no catalogue HTML to
crawl). Cover pages are OCR'd via GLM-OCR (`pdfs/ocr-cache/` cache,
`pdftotext -layout -l 1` first, OCR fallback) to harvest title, date,
edition, and abstract.

The broader named publications (PostScript Language, Glyph List, XFA,
character collections) live in different upstream repos
(`adobe-type-tools/agl-aglfn`, `adobe-type-tools/cmap-resources`, the
PDF Association mirror at `pdfa.org/norm-refs/…`). Each gets its own
fetcher strategy in `lib/adobe_fetcher/sources/`.

## Repo layout (planned — modeled on relaton-data-iala)

```
data/                     # YAML per Adobe publication (e.g. atn5014.yaml, adobe-glyph-list.yaml)
Gemfile                   # psych pin + relaton (with Adobe flavor) + pubid (rt-new-lutaml-model)
crawler.rb                # entry point → AdobeFetcher::Indexer.build (rebuilds index-v1 + index-v2)
check_data.rb             # round-trip validator, exit 1 on mismatch
exe/adobe-fetch           # binstub ($LOAD_PATH + require "adobe_fetcher")
lib/adobe_fetcher.rb      # module + constants + autoload entries
lib/adobe_fetcher/
  docid.rb                # AdobeFetcher::Docid value object (typed TechNote + generic slug ids)
  source.rb               # .url / .adobe / .local constructors
  source_entry.rb         # AdobeFetcher::SourceEntry — uniform Entry type across sources
  http.rb                 # Http seam (NetHttp + Fake adapters)
  yaml_store.rb           # owns all YAML I/O, uses Relaton::Adobe::Item
  sources/
    base.rb               # Sources::Base — abstract #each_entry
    tech_notes.rb         # Sources::TechNotes — font-tech-notes git repo enumerator
  pdf_downloader.rb       # caches PDFs by URL hash under pdfs/
  cover_page_ocr.rb       # GLM-OCR wrapper (clone of IALA's, same endpoint/key)
  cover_page_parser.rb    # OCR/text → structured fields (title, date, edition, number)
  publication_fetcher.rb  # orchestrates → emits YAML
  indexer.rb              # AdobeFetcher::Indexer.build (clean-rebuild v1 + v2)
  scrape.rb               # Thor subclass (fetch + index tasks)
spec/adobe_fetcher/       # rspec specs (no doubles — real instances)
spec/fixtures/           # cover-page text samples, YAML samples
reference-docs/           # PDF Association normative-refs PDFs, canonical citations
sources/                  # gitignored — font-tech-notes clone lives here
pdfs/                     # gitignored PDF cache
pdfs/ocr-cache/           # gitignored OCR markdown cache
index-v1.yaml             # generated, committed (flat string docid index)
index-v2.yaml             # generated, committed (structured pubid index)
```

## Architecture

All modules use Ruby `autoload` declared in `lib/adobe_fetcher.rb`.
No `require_relative` anywhere in `lib/`. The binstub adds `lib/` to
`$LOAD_PATH` and calls `require "adobe_fetcher"`.

Dependency injection mirrors IALA: fetchers accept `yaml_store:` and
`http_backend:` parameters; specs install `AdobeFetcher::Http::Fake`.

`AdobeFetcher::YamlStore` owns all YAML I/O (UTF-8, idempotent,
serialized via `Relaton::Adobe::Item`). No `File.write` outside
`YamlStore`.

`AdobeFetcher::Docid` is the single value object across both observed
shapes: typed TechNote ids (`ATN5014`, `Adobe TN 5014`,
`urn:adobe:tech-note:5014`) and slug-keyed Publication ids
(`adobe-glyph-list`, `Adobe Publication Adobe Glyph List`). Parses/
URN delegate to `Pubid::Adobe`; the title-based citation form is
owned by Docid (presentational) so Pubid stays structural.

`AdobeFetcher::SourceEntry` is the uniform entry type yielded by every
source. Each entry knows how to build its own Docid via `#to_docid`
(polymorphism, not type-dispatch in the orchestrator) and exposes
location fields (`#absolute_path`, `#bytes_url`, `#web_url`,
`#filename`) with nil defaults. Adding a new source = adding one
`Sources::<Name> < Sources::Base` file that yields SourceEntry
instances.

## Companion repos that must move in lockstep

This data repo is one of three coordinated changes:

| Repo | Path | Branch base | Adds |
|------|------|-------------|------|
| `relaton-data-adobe` (here) | `src/relaton/relaton-data-adobe` | `main` | Scraper, `data/*.yaml`, indexes |
| `relaton` (unified gem) | `src/relaton/relaton` | `feat/adobe-flavor` PR [relaton/relaton#56](https://github.com/relaton/relaton/pull/56) | `lib/relaton/adobe/*` inside the unified gem |
| `pubid` | `src/mn/pubid` | `rt-new-lutaml-model` | `lib/pubid/adobe/*` (TechNote + Publication identifiers) |

The Adobe Relaton flavor lives INSIDE the unified `relaton` gem at
`lib/relaton/adobe/` (mirrors IALA's in-monorepo shape — not a separate
flavor gem). Until relaton/relaton#56 merges, this repo's `Gemfile`
uses `path: "../relaton"` against a local checkout on
`feat/adobe-flavor`. Flip back to
`git: "https://github.com/relaton/relaton.git", branch: "main"` once
the PR lands.

## Commands

```bash
bundle install
bundle exec adobe-fetch                              # scrape all sources, write data/
bundle exec adobe-fetch --source=tech-notes          # narrow to one source
bundle exec adobe-fetch --pdfs                       # download/clone PDFs + OCR cover pages
bundle exec adobe-fetch index                        # rebuild index-v1 + index-v2
bundle exec ruby crawler.rb                          # rebuild indexes only
bundle exec ruby check_data.rb                       # round-trip validate data/
bundle exec rspec spec/                              # run specs (74 examples, no doubles)
```

## Crawler + check_data contracts

`crawler.rb` → `AdobeFetcher::Indexer.build` indexes every
`data/*.yaml` by primary docid into `index-v1.yaml` (string docid →
file) and `index-v2.yaml` (structured `Pubid::Adobe` identifier →
file, `pubid_class: Pubid::Adobe::Identifier`). Calls `remove_all`
first; both indexes are **rebuilt from scratch each run**. v1 sorted
by filename; v2 sorted by pubid. The `relaton/support` crawler
workflow zips each `index*.yaml` into `index*.zip` and commits both.

`check_data.rb` round-trips every YAML through
`Relaton::Adobe::Item.from_yaml` → `to_yaml` and diffs against the
source. Exit 1 on any byte mismatch. Adobe `ext` fields round-trip
natively because they're typed on `Relaton::Adobe::Ext` — **no merge
hack**.

## Gemfile (template)

```ruby
gem "psych", "~> 5.2.6"   # 5.3.0 breaks YAML round-trip
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"
gem "pubid",   git: "https://github.com/metanorma/pubid.git",
               branch: "rt-new-lutaml-model"
gem "thor", "~> 1.3"
gem "nokogiri"
gem "net-http-persistent"
gem "activesupport", require: false
```

While the `Relaton::Adobe` flavor PR (relaton/relaton#56) and the Adobe
`pubid` flavor are still in flight, the actual Gemfile uses `path:`
references to the local working trees. HTTPS git sources so the GH
Action can clone anonymously once both have merged.

## Conventions

- **Always read/write YAML with `encoding: "UTF-8"`** — Adobe titles
  contain typographic punctuation (curly quotes, em-dashes) and CJK
  text in the character-collection publication names.
- **Pin `psych ~> 5.2.6`** — 5.3.0 silently breaks the round-trip.
- **GitHub Actions reuse `relaton/support` workflows** — do not write
  custom ones. Same `check_data.yml` + `crawler.yml` shape as IALA.
- **Strict fetches — no fallbacks.** When a map (DOCTYPE, SOURCE_REPO)
  is missing a key, `.fetch(key)` raises. Silent defaults produce
  malformed data.
- **Never use `double()` in specs** — instantiate real objects or use
  `Struct.new` for plain data.
- **Never use `require_relative`** in library code — Ruby `autoload`
  declared in the immediate parent namespace's file.
- **Never use `send` to call private methods, `instance_variable_set/get`,
  or `respond_to?` for type checking.**
- **Never hand-roll `to_h`/`from_h`/`to_yaml`/`from_yaml` on model
    classes** — declare attributes + mappings; let the framework
    (lutaml-model / relaton-bib) serialize.
- **Never commit to `main`, never push tags, never add AI attribution**
  (no `Co-authored-by:`, no "Generated with" footers).

## Reference files in sibling repos

- `relaton-data-iala/CLAUDE.md` + `AGENTS.md` — architectural pattern
  source for the data repo. Read first.
- `relaton-data-iala/lib/iala_fetcher/` — copy/adapt each file.
- `relaton-data-iala/backfill/glm_ocr.rb` — GLM-OCR API template
  (also see `lib/iala_fetcher/cover_page_ocr.rb` for the maintained
  library version).
- `relaton/relaton/lib/relaton/iala/` — `Relaton::Adobe` in-monorepo
  flavor pattern source (the v3 unified-gem architecture).
- `mn/pubid/lib/pubid/iala/` — `Pubid::Adobe` flavor pattern source.
- `relaton/relaton#39` — the parent issue tracking this work.
- `relaton/relaton#56` — the Adobe flavor PR.
