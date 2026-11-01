# Hayagriva, BibLaTeX, and BibTeX mappings

This reference documents the **implemented import** from BibLaTeX and BibTeX into Hayagriva and a **proposed export mapping** from Hayagriva to each format. Export is not implemented. Export recommendations below are design decisions for a future converter, not promises made by the current API.

The formats overlap, but they are not interchangeable. BibLaTeX has a richer data model than the traditional BibTeX standard styles, and Hayagriva represents containers and events as nested entries. Conversion is therefore not generally reversible. Importing a `.bib` file does not retain enough information to reproduce its original syntax, entry types, field boundaries, or inheritance links.

- [Scope and sources](#scope-and-sources)
- [Implemented import](#implemented-import-biblatex--hayagriva): types, parent construction, fields, roles, and losses
- [Proposed export](#proposed-export-hayagriva--biblatex--bibtex): relationship selection, target types, fields, and examples
- [Strict BibLaTeX mapping](#strict-biblatex-mapping)
- [Strict BibTeX mapping](#strict-bibtex-mapping)
- [Compatibility and future validation](#compatibility-and-future-validation)

## Scope and sources

The implementation described here is the source in this checkout (Hayagriva 0.10.1, declaring `biblatex = "0.12.0"`):

- [Import API](../src/io.rs): `from_biblatex_str` and `from_biblatex`.
- [Conversion implementation and regression tests](../src/interop.rs): `TryFrom<&biblatex::Entry> for Entry`, person/date/string conversions, and `ed_role`.
- [Native model](../src/lib.rs), [entry types](../src/types/mod.rs), and [YAML format](file-format.md).
- [CLI](../src/main.rs): the `bibtex` and `biblatex` input formats use the same importer. They do not select different mapping rules.
- [`biblatex` parser](https://github.com/typst/biblatex): parsing, field aliases, typed getters, and supported bibliography inheritance precede Hayagriva conversion. These are dependency behavior, not a separate BibTeX conversion pass in Hayagriva.

The supplied manuals define the target formats:

| Source | Version | Relevant sections |
| :--- | :--- | :--- |
| [The biblatex Package](spec/biblatex.pdf) | 3.22a, September 24, 2026 | §2.1 entry types; §2.2 fields and aliases; §2.3 usage differences; §3.4 extended names; Appendix A.1 source mappings; Appendix B inheritance |
| [BibTeXing](spec/btxdoc.pdf) | February 8, 1988; documents BibTeX 0.99b | §2.2 standard-style changes; §3.1 entry types; §3.2 fields; §4 usage tips |
| [Designing BibTeX Styles](spec/btxhak.pdf) | February 8, 1988 | §5 style processing, names, and case handling |
| [BibTeX Tips and FAQ](spec/btxFAQ.pdf) | 1.1, January 2007 | §§2.3 and 3.3 online references; §3.5 style design |

Here, **BibTeX** means the vocabulary and behavior of the traditional standard styles (`plain`, `abbrv`, `alpha`, `unsrt`), unless an extension is explicitly mentioned. BibTeX syntax permits extra fields, but a style can ignore them. A field being writable in a `.bib` file does not mean standard styles will display it. Likewise, BibLaTeX's default data model and its standard bibliography drivers are distinct: some accepted types require a custom style to format them specifically.

Names such as `article`, `anthos`, and `page-range` below use YAML spelling. Rust variants are `Article`, `Anthos`, etc.; the YAML field for editors is `editor`, even though its Rust setter is `set_editors`.

## Implemented import: Bib(La)TeX → Hayagriva

### Pipeline and error handling

With the `biblatex` feature enabled (enabled by default), `from_biblatex_str` first calls `biblatex::Bibliography::parse`, then converts each parsed entry. The parser interprets `.bib` syntax, abbreviations, names, aliases, and supported `crossref`/`xdata` inheritance. Hayagriva receives the resulting field values, not a source-preserving document. Calling `from_biblatex` or `Entry::try_from` with manually constructed parser objects requires callers to account for that distinction.

Hayagriva constructs its own parents from the entry type and fields. It does **not** turn a `crossref` key into a reference to another Hayagriva library entry. Generated parents use the child's citation key internally and are nested values, not separately keyed bibliography records. An explicit source entry can also remain a separate library record.

Missing fields usually leave the corresponding native field unset. Most accessed typed getters pass through `map_res`, which propagates type errors. The author getter is an exception: failure is ignored. `langid` errors are ignored, while a `language` getter error can propagate. Literal dates, invalid URLs, unrecognized eprint services, and unparseable page totals can be discarded without an import error. Unaccessed fields are not validated by this converter. A successful import is therefore neither full specification validation nor proof of lossless conversion.

`from_biblatex` collects conversion errors across entries and returns errors instead of a partial library if any conversion fails. The converter does not call the parser's entry-requirements verifier; even an entry missing fields required by a bibliography style can import.

### Entry types

`P` is the ordinary publication parent. “Expand MV” means the importer can create an additional multivolume node **only when both `maintitle` and `volume` getters report a value**. It is not a general test for a multivolume work. Invalid typed values may still cause conversion to fail later.

“Both” identifies traditional BibTeX types also accepted by BibLaTeX. The remaining explicit types belong to BibLaTeX. `conference` is a legacy alias, not a Hayagriva `conference` event.

| Source type | Vocabulary | Hayagriva item | P | Expand MV | Default `genre` if `type` absent |
| :--- | :--- | :--- | :--- | :---: | :--- |
| `article` | Both | `article` | `periodical` | No | |
| `book` | Both | `book` | — | Yes | |
| `booklet` | Both | `misc` | — | No | |
| `inbook` | Both, different meanings | `chapter` | `book` | Yes | |
| `incollection` | Both | `anthos` | `anthology` | Yes | |
| `inproceedings`, `conference` | Both | `article` | `proceedings` | Yes | |
| `manual` | Both | `reference` | — | No | |
| `mastersthesis` | Both | `thesis` | — | No | `Master's thesis` |
| `phdthesis` | Both | `thesis` | — | No | `Doctoral dissertation` |
| `techreport` | Both | `report` | — | Yes | `technical report` |
| `misc` | Both | `misc` | — | No | |
| `proceedings` | Both | `proceedings` | — | Yes | |
| `unpublished` | Both | `manuscript` | — | Yes | |
| `thesis` | BibLaTeX | `thesis` | — | No | |
| `report` | BibLaTeX | `report` | — | Yes | |
| `mvbook` | BibLaTeX | `book` | — | No | |
| `bookinbook` | BibLaTeX | `book` | `book` | Yes | |
| `suppbook` | BibLaTeX | `misc` | `book` | Yes | |
| `periodical` | BibLaTeX | `periodical` | — | Yes | |
| `suppperiodical` | BibLaTeX | `misc` | `periodical` | Yes | |
| `collection` | BibLaTeX | `anthology` | — | Yes | |
| `mvcollection` | BibLaTeX | `anthology` | — | No | |
| `suppcollection` | BibLaTeX | `misc` | `anthology` | Yes | |
| `reference` | BibLaTeX | `reference` | — | Yes | |
| `mvreference` | BibLaTeX | `reference` | — | No | |
| `inreference` | BibLaTeX | `entry` | `reference` | Yes | |
| `mvproceedings` | BibLaTeX | `proceedings` | — | No | |
| `patent` | BibLaTeX | `patent` | — | No | |
| `online`, `electronic`, `www` | BibLaTeX and aliases | `web` | — | No | |
| `software` | BibLaTeX | `misc` | — | No | |
| `dataset` | BibLaTeX | `repository` | — | No | |
| `set` | BibLaTeX | `misc` | — | No | |
| `xdata` | BibLaTeX | `misc` | — | No | |
| Other types | Including BibLaTeX non-standard types | `misc` | — | No | |

The last row includes `artwork`, `audio`, `bibnote`, `commentary`, `image`, `jurisdiction`, `legislation`, `legal`, `letter`, `movie`, `music`, `performance`, `review`, `standard`, `video`, and custom types. The fact that BibLaTeX recognizes a type does not imply that the importer gives it a dedicated native type. In particular, `video` does not import as `video`, and `review` does not receive the `article` mapping merely because BibLaTeX's standard styles treat it as an article.

`set` membership is not reconstructed. The `xdata` row describes conversion of an entry exposed to the converter; it is not a claim that Hayagriva implements BibLaTeX's non-citable data-container semantics. Inheritance processing belongs to the parser.

### Parent construction and destinations

The following symbols describe **physical field placement**, not inherited getter results:

| Symbol | Meaning |
| :--- | :--- |
| `I` | The cited item |
| `P` | Ordinary publication parent, if the type table specifies one |
| `M` | Additional multivolume node, if expansion is triggered |
| `C` | Conference/event parent |
| `S` | Series parent |
| `B` | Publication-field destination: `P` if present, otherwise `I` |

Parents are built as follows:

1. Create `P` even if it will have no title or other fields. When MV expansion is enabled and triggered, create `I → P → M`, with `M` having `P`'s type. Without an ordinary parent, create `I → M`, with `M` having `I`'s type. In this latter case `B` is still **I**, not M.
2. Put `maintitle` and `volumes` on `M`. Without expansion, neither is imported. Thus `@mvbook` itself does not trigger this expansion, and `volumes` alone is not enough.
3. For `proceedings`, `mvproceedings`, or `inproceedings`, create `C: conference` if any of `eventdate`, `eventtitle`, or `venue` is retrieved. Attach `C` directly to `I`, alongside any publication parent. A literal event date can trigger creation even though no native date is stored.
4. If `series` is present, create a title-bearing `S` and attach it to `M`, else `P`, else `I`. Give `S` the type of the node it attaches to. A series has no dedicated native type or relationship label. No series number is moved onto `S`.

For an in-proceedings paper with all expansions, the shape is:

```text
I: article
├── P: proceedings
│   └── M: proceedings
│       └── S: proceedings
└── C: conference
```

The maximum is four generated parent nodes in total, not four direct parents. Parent type, position, and title alone cannot always distinguish a series from a multivolume collection in an arbitrary native entry.

### Fields

Aliases below describe the parser getter names used by the importer. When both canonical and alias fields are present, the canonical getter prefers its own field. They are not concatenated. Date getters prefer `date` over component fields such as `year` and `month`.

| Source field(s) | Native destination | Implemented behavior |
| :--- | :--- | :--- |
| Citation key | `I` key | Preserved as the library key; not the BibTeX `key` field |
| `author` | `I.author` | Parsed persons; getter errors ignored |
| `bookauthor` | `P.author` | Only when an ordinary parent exists |
| `editor`, `editora`, `editorb`, `editorc` and role fields | `I.editor` / `I.affiliated` | See role table; all remain on I |
| `holder`, `annotator`, `commentator`, `translator`, `afterword`, `foreword`, `introduction` | `I.affiliated` | Same-named native roles |
| `title`, `shorttitle` | `I.title.value`, `I.title.short` | Short title only read when `title` exists |
| `maintitle` | `M.title` | Only with MV expansion |
| `journaltitle` / `journal` | `P.title` | Only for `article` |
| `booktitle` | `P.title` | For other types with an ordinary parent |
| `eventtitle` | `C.title` | Only when a conference node is created |
| `eventdate` or event date components | `C.date` | Typed dates only |
| `venue` | `C.location` | Event location, distinct from publisher location |
| `date` or `year`, `month`, `day` | `I.date` | Typed dates only; see date losses below |
| `edition` | `B.edition` | Typed number or text fallback |
| `issue` | `B.issue` | Only for `article` and `proceedings` |
| `issuetitle` | `B.title` | Only for `article` and `proceedings`; overwrites an earlier title |
| `number` | `P.issue`, `I.issue`, or `I.serial-number.serial` | If P exists, always P.issue. Otherwise serial for native `report`, `patent`, `entry`, `reference`; issue for every other type. Runs after `issue`, overwriting it |
| `volume` | `B.volume` | Typed number or text fallback |
| `volumes` | `M.volume-total` | Only with MV expansion |
| `version` | `I.serial-number.version` | Verbatim text |
| `doi` | `I.serial-number.doi` | String from parser getter |
| `isbn`, `issn`, `isan`, `ismn`, `iswc` | Same-named `I.serial-number` keys | Verbatim text |
| `eprint` + `eprinttype` / `archiveprefix` | `I.serial-number.arxiv` or `.pmid` | Service compared case-insensitively: `arxiv` or `pubmed`; all other services discarded |
| `url` | `I.url.value` | Only if `Url::parse` succeeds |
| `urldate` or URL date components | `I.url.date` | Typed dates only; only read after a valid URL |
| `publisher` | `B.publisher.name` | Parsed list joined with comma and space; list boundaries lost |
| `location` / `address` | `B.publisher.location` | Also retained in a location-only publisher when no publisher name exists; not `B.location` |
| `organization` | `B.organization` | Parsed list joined with comma and space |
| `institution` / `school` | `B.organization` | Fallback only if `organization` absent |
| `howpublished` | `B.note` | Can later be overwritten if B is I |
| `pages` | `I.page-range` | Typed single pages/ranges; otherwise reparse flattened text or retain text |
| `pagetotal` | `B.page-total` | Only if flattened text parses as the target numeric value |
| `note` | `I.note` | Overwrites root `howpublished` |
| `annotation` / `annote`, then `addendum` | `I.note` | Used only if native note is unset, including a note already set by `howpublished`; absence, not an empty string, controls fallback |
| `abstract` | `I.abstract` | Formattable string |
| `type` | `I.genre` | Takes precedence over defaults in the entry-type table |
| `series` | `S.title` | See parent construction |
| `chapter` | `I.chapter` | Unit/section number, independent of native entry type |
| `language`, `langid` | `I.language` | First language if present, otherwise langid; only a typed Unicode language identifier is stored. An unrecognized first literal language is ignored, without retrying langid or later languages |

Important ordering effects follow directly from this table. For an article with both `journaltitle` and `issuetitle`, only the issue title survives on `P.title`. For an ordinary book, `howpublished` can be replaced by `note`; `annotation` does not replace an existing `howpublished`. For an in-collection contribution, `howpublished` can survive on P while `note` is stored on I.

The importer does not redistribute identifiers to the publication parent: even a journal ISSN stays on I. It also puts editors on I rather than P. These are implementation facts, not a recommendation for how to author native entries.

### People and roles

Persons retain family name (`name`), given name, prefix, and suffix. With `useprefix=true`, the prefix is folded into `name` and the native `prefix` is cleared. Native `comma-suffix` is set to false and `alias` is unset. Original name spelling, parsing syntax, and name options cannot be reconstructed from these fields alone.

The four editor lists are processed in order (`editor`, `editora`, `editorb`, `editorc`). Ordinary editor lists are merged into `I.editor`; other lists become role-bearing affiliated groups. Missing role annotations mean ordinary editors. Original list slots are not retained.

| Editor role value | Native result |
| :--- | :--- |
| `editor`, `continuator`, `redactor`, `reviser` | `I.editor`; distinctions lost |
| `compiler`, `founder`, `collaborator`, `organizer`, `director` | `I.affiliated`, same-named role |
| `producer` | `I.affiliated`, `producer` |
| `scriptwriter` | `I.affiliated`, `writer` |
| `writer` on source `video` | `I.affiliated`, `writer` |
| `none` on source `video` or `music` | `I.affiliated`, `cast-member` |
| Other values (including `writer` / `none` outside these contexts) | `I.affiliated`, unknown role preserving its value |

The media-specific conditions use the **source** type, even though those source entries import as `misc`. They reflect style/export conventions, not general BibLaTeX standard-role equivalents.

Unknown roles are retained in the in-memory `PersonRole::Unknown(String)` variant. That variant is marked `serde(skip)` in the native model, so this is **not** a guarantee that the role can be serialized to YAML and read back. A YAML conversion involving such a role can fail; preserve source provenance separately if unknown roles matter.

### Values that change or disappear

- **Dates:** a point date keeps its available precision. An open interval keeps its endpoint but loses “before”/“after”; a closed interval keeps the **second endpoint**. Uncertain and approximate flags merge into `approximate = uncertain || approximate`; the native season is unset. Literal dates are not stored. This applies to publication, event, and access dates.
- **Strings:** normal, case-protected/verbatim, and math chunks become corresponding native chunks for formattable strings. Fields flattened with `format_verbatim` lose those chunk distinctions. The parsed representation is not original TeX source; commands, abbreviation references, whitespace, and brace layout are not generally recoverable.
- **Numbers:** edition and volume accept typed integers or text. Numeric conversion can normalize spelling (for example Roman numerals), and the code casts typed `i64` values to native `i32`; do not infer an arbitrary-size lossless mapping. Serial numbers remain strings rather than numeric ranges.
- **Lists:** publisher and organization lists are flattened. Splitting a resulting string on commas cannot recover the original list, since commas can occur within a name.
- **Titles:** subtitles and title add-ons are not imported or joined to the main title. Container short titles such as `shortjournal` are not imported.
- **Unsupported metadata:** examples include `eid`, `isrn`, `eprintclass` / `primaryclass`, `entrysubtype`, `part`, `pagination`, `bookpagination`, original-publication fields, `pubstate`, `shortauthor`, `shorteditor`, `namea`–`namec`, `authortype`, `keywords`, `file` / `pdf`, `library`, sorting/label/shorthand fields, related-entry metadata, and set membership. A field not accessed by `interop.rs` has no native mapping, even if the parser understands it.
- **Document structure:** source comments, preambles, macro definitions, alias keys, and inheritance provenance have no source-preserving representation in the converted native library.

### Traditional BibTeX differences

The single importer follows the mapping above for both input labels. It does not repair every difference between traditional BibTeX semantics and BibLaTeX semantics (see BibLaTeX §2.3 and BibTeXing §§2.2–3.2).

| Traditional BibTeX input | Current interpretation / limitation |
| :--- | :--- |
| `journal`, `address`, `school`, `annote` | Getter aliases for `journaltitle`, `location`, `institution`, `annotation` |
| `year` and `month` (including month abbreviations) | Parsed through the dependency's date getter, not copied to separate native fields |
| `conference` | Alias for `inproceedings`; creates an article in proceedings |
| `inbook.title` | Kept on the chapter item, while only `booktitle` fills the book parent. Traditional BibTeX uses `title` for the book and does not require a separate contribution title |
| `proceedings.address`, `inproceedings.address` | Routed to `B.publisher.location`. BibTeXing §2.2 item 10 uses this address for the conference location; it does not create C without event fields |
| `series` plus `number` | Series becomes a same-type parent; number remains on B as issue or serial according to the rules above |
| Extra `doi`, `url`, etc. | May import even though traditional standard BibTeX styles ignore these fields |
| Missing required style fields | Does not by itself cause conversion failure |

## Proposed export: Hayagriva → BibLaTeX / BibTeX

Everything in this section is **proposed**, including warnings, fallback behavior, profiles, and validation. There is no `to_biblatex` or `to_bibtex` API in this checkout.

### Native capabilities and missing information

The mapping must start from the actual `Entry` model, not from everything YAML syntax permits. In this checkout, `Entry` has a fixed set of bibliographic fields and owned nested parents. Its deserializer has no flattened map for extra fields. Unknown YAML field names are ignored by the derived entry-field deserializer, not retained for export. Do not use arbitrary YAML keys as a preservation mechanism.

| Capability | Hayagriva in this checkout | Strict BibLaTeX target | Strict traditional BibTeX target |
| :--- | :--- | :--- | :--- |
| Keywords / tags | No `keywords` field; import discards it | `keywords` exists, but cannot be reconstructed from native data | No standard-style keyword field |
| Publication hierarchy | Nested `parent` entries; multiple parents and levels | Flatten to container/event/series fields, or explicitly generate supported relationships | Flatten to supported fields, or explicitly generate a single publication `crossref` |
| Key-based cross-references | No native `crossref`, `xref`, or `xdata` field; a nested parent's internal key is not an independent reference | `crossref`, `xref`, and `xdata` have different semantics | `crossref` exists; no standard `xref` or `xdata` |
| Arbitrary custom fields | No general custom-field store | Require an explicit custom data model outside the strict default profile | Arbitrary fields are syntactically possible but outside the strict standard-style profile |
| Extensible identifiers | `serial-number` is a dictionary of strings | Map only recognized schemes with matching semantics | No general identifier dictionary; supported `number` is context-specific |
| Additional contributor roles | Fixed roles plus an in-memory unknown-role variant | Dedicated fields and limited typed editor lists | Author/editor only in standard styles |
| Original publication | Can be represented by an `original` parent | Selected metadata can map to `origtitle`, `origdate`, `origpublisher`, `origlocation` | No corresponding structured original-publication fields |

Native `genre`, `note`, and `serial-number` are not substitutes for a custom-field store. In particular, do not map topics or keywords into `genre`, encode arbitrary field names as serial schemes, or parse prose notes to invent structured metadata. Unknown native roles also have the YAML serialization limitation described in the import section.

If an application needs to retain BibLaTeX-only information such as keywords across native edits, it must keep an explicit external metadata record or extend the native schema. That is a separate preservation feature. A future exporter could accept such a record, but must validate each supplied field against the selected target; it cannot be inferred from the existing `Library`. Strict BibLaTeX may emit validated external `keywords`; strict BibTeX must reject or explicitly omit them.

### Strict target contracts

Select the target **before** selecting types or fields. These are separate export contracts, not one permissive “Bib(La)TeX” writer with interchangeable labels.

| Contract | Allowed output | Outside the contract |
| :--- | :--- | :--- |
| `biblatex-strict` | The supplied BibLaTeX 3.22a default data model, its declared types and fields, valid value types, and documented relationships | Unregistered arbitrary fields/types, undeclared package extensions, invalid field values, unresolved generated keys |
| `bibtex-strict` | Traditional types and per-type standard-style fields from BibTeXing §3, plus the standard `key` and `crossref` mechanisms | BibLaTeX-only types/fields, modern DOI/URL/ISBN extensions, custom `.bst` fields, `xdata`, `xref`, arbitrary fields |

Strictness describes **target conformance**, not losslessness. BibLaTeX's default model includes non-standard-driver types such as `video` and `jurisdiction`; their use can be format-valid even if a standard bibliography style falls back to `misc`. Conversely, writing `doi` into a syntactically valid `.bib` file does not satisfy this document's strict traditional BibTeX contract. A style capability check is an additional check, separate from target validity.

Use an independent loss policy for both targets:

| Loss policy | Required behavior |
| :--- | :--- |
| `error` (default) | Do not return a successful export when any populated bibliographic value or relationship cannot be represented, is ambiguous, or would change meaning. Return diagnostics for the user to resolve |
| `omit` (explicit opt-in) | Omit unsupported values or apply the documented type fallbacks, reporting each lost value and classification/relationship change |
| `text` (explicit opt-in) | Put selected unsupported information into an allowed `note` or `howpublished` field only under a documented template, reporting loss of structure. Never create forbidden target fields |

Target violations, invalid keys, unresolved references, and conflicting values remain errors under every loss policy until resolved. Missing required bibliographic data prevents a conforming result, except where the target explicitly permits its omission. `misc` is a classification fallback under an acknowledged loss policy, not an automatic route around validation. Do not switch the target to BibLaTeX because a strict BibTeX export is difficult.

A diagnostic should identify the citation key, native node path (for example `parent[1].title`), source field/value, selected target, reason, and proposed omission/fallback. Successful output under a lossy policy must still satisfy that target's contract. Losing original source syntax is outside the bibliographic loss check: the exporter is operating on the current native model, not promising byte-for-byte reconstruction.

Flattening is not inherently a loss: a selected book parent represented correctly as `booktitle`, publisher, and other container fields still expresses bibliographic containment. Loss means omitted or changed bibliographic meaning, not merely replacing a nested native representation with flat target fields. Do not report an ordinary, fully mapped parent as lost solely because no separate parent record was emitted.

### Export contract and parent selection

Both strict targets should default to self-contained records: flatten selected container metadata into each cited entry. This is a serialization choice, not a claim that cross-references are non-standard. Relationship-preserving output is a separate explicit option with the target-specific rules below.

Select relationships by meaning and type, not a blanket “take the first parent” rule:

1. Identify the publication container appropriate to the cited item (periodical, proceedings, book, anthology, or reference work).
2. Select a conference parent separately for event metadata; it is not the publication container.
3. Identify a multivolume collection and a series only where the structure and user intent establish their roles. A same-type title-only ancestor can be either. Accept an explicit relationship selection/override; if ambiguous, report an error under the default loss policy, or omit the disputed mapping under an explicit lossy policy.
4. Map fields from their selected nodes using the tables below. Resolve root/container conflicts explicitly; report competing candidates rather than dropping one silently. Additional parents, unsupported relationships, and unused metadata must produce loss diagnostics.

Because imported editors are on I, the exporter should accept root editors as the flattened `editor` list for imported contribution entries when no conflicting container list exists. This permits useful re-export, but it cannot determine whether those people originally edited the item or its container. Do not automatically merge conflicting root and container names.

Do not treat all same-type parents as multivolume collections, infer `software` from `misc`, or infer `dataset` from every `repository`. Those distinctions were lost or are broader in the native model. Bibliographic equivalence is the goal; exact reconstruction of the original `.bib` is impossible without retaining separate source provenance.

#### Relationships in strict BibLaTeX

`crossref` establishes a publication relationship and inherits data under BibLaTeX/Biber's field-transfer rules. `xref` establishes a relationship without inheriting data. `xdata` inherits data without establishing a publication relationship. They are not three interchangeable spellings of native `parent` (BibLaTeX §2.2.3, §2.4.1, §3.14.6, and Appendix B).

When relationship output is requested, promote only a selected publication container to an independently keyed record and use `crossref` only where the target's inheritance rules preserve the intended meaning. Otherwise keep the child fields explicit. A conference sibling remains event metadata (`eventtitle`, `eventdate`, `venue`); it must not become the publication crossref. A selected `original` parent can supply original-publication fields; generic association is not sufficient to invent an `xref` or `related` relationship. Reusable publication data may be placed in generated `xdata` records as an optimization, but a native parent is not automatically an `xdata` container.

Reserve all existing citation keys before generating parent/data-record keys. Require explicit identity or a documented semantic comparison before sharing promoted parents; equal titles or equal internal parent keys do not establish identity. Emit every referenced record, avoid cycles, and verify the effective child metadata after inheritance. Never merge conflicting parent records merely to reduce duplication.

#### Relationships in strict BibTeX

Traditional BibTeX supports `crossref`, but not BibLaTeX's `xref` or `xdata`. Use at most one selected publication container as a child's crossref. Emit the parent after every referencing child and avoid nested crossrefs. Transfer fields according to traditional inheritance: a proceedings parent's `title` does not automatically become the child's `booktitle`; a parent may need an explicit `booktitle` solely for inheritance, as in BibTeXing §2.2 item 3. This is a documented crossref exception to the normal parent-type field allowlist.

Traditional crossrefs can cause a parent to appear in the bibliography when enough children are cited, so relationship output also has a rendering consequence. Default flattening avoids that change. Multiple native publication parents, events, and series cannot all be represented as independent crossrefs on one record. Flatten the selected representable relationships and report remaining structural loss; under `error`, require a resolution instead of silently choosing the first parent. Parent-key generation and identity checks follow the same rules as strict BibLaTeX.

### Reading the export mappings

The following sections define each strict target independently. Context-specific type rules take precedence over generic fallbacks. Every fallback or missing counterpart is subject to the selected loss policy; under the default `error` policy it is a failure requiring resolution, not an automatic omission. Together the type tables cover every current native `EntryType`; unknown future variants require the same explicit treatment.

`I`, `P`, `M`, `C`, and `S` mean nodes selected for semantic roles, not fixed array positions. `B` means the selected publication: P for a contribution, otherwise I. Field rows identify semantic candidates; target validation must also check the selected entry type and value datatype. A listed field is not a blanket assertion that every bibliography driver prints it for every type.

### Strict BibLaTeX mapping

#### BibLaTeX entry types

| Native item / selected context | BibLaTeX type | Qualification |
| :--- | :--- | :--- |
| `article` in `periodical` or `newspaper` | `article` | Requires a container title for `journaltitle` / `journal` |
| `article` in `proceedings` | `inproceedings` | Conference parent supplies additional event data |
| `article` in `blog` / `web`, or without an identifiable publication container | `online` if intrinsically online; otherwise `misc` | A URL alone does not make every article an online resource |
| `chapter` in `book` | `inbook` | Apply the different title rules below |
| `anthos` in `anthology` | `incollection` |  |
| `entry` in `reference` | `inreference` | Reference-work distinction lost in BibTeX |
| `chapter`, `anthos`, `entry` without a usable container | `misc` | Warn about missing relationship |
| `book` in `book` as an independently titled contained work | `bookinbook` | Requires explicit containment interpretation |
| Whole `book` | `book` | `mvbook` only for an explicitly identified whole multivolume set |
| `anthology` | `collection` | `mvcollection` only for an explicit whole multivolume set |
| `reference` | `reference`; `manual` if explicitly technical documentation | `mvreference` only for an explicit whole multivolume set; native type alone cannot choose manual |
| `proceedings` | `proceedings` | `mvproceedings` only for an explicit whole multivolume set |
| `periodical`, `newspaper` as the cited item | `periodical` | A whole periodical/issue is not a journal article |
| `report` | `report` | Preserve genre as `type` where supported |
| `thesis` | `thesis` | Never assume a doctoral degree; BibLaTeX requires a suitable `type` |
| `manuscript` | `unpublished` | Note required for traditional BibTeX; optional for BibLaTeX |
| `patent` | `patent` | Patent classification and holder role lost in standard BibTeX |
| `web`, `blog`, `post`, `thread` | `online` | For intrinsically online resources |
| `repository` | `online` by default; `software` or `dataset` only with explicit classification | Dataset import to repository is not an invertible type correspondence |
| `misc` | `misc` | No inferred booklet/software/set/xdata provenance |
| `misc` with an explicitly identified supplemental relationship | `suppbook`, `suppcollection`, or `suppperiodical` for the matching container | Native `misc` plus a parent alone is insufficient to infer supplementation |
| `artwork` | `artwork` | BibLaTeX default-model type; specific rendering depends on style |
| `case` | `jurisdiction` | BibLaTeX default-model type; specific rendering depends on style |
| `legislation` | `legislation` | BibLaTeX default-model type; specific rendering depends on style |
| `performance` | `performance` | BibLaTeX default-model type; specific rendering depends on style |
| `video`, `audio`, `letter` | Same-named BibLaTeX type | BibLaTeX default-model types; specific rendering depends on style |
| `scene`, `conference`, `exhibition`, `original` as independently cited items | `misc` fallback | No exact default-model type; classify explicitly or acknowledge the loss |

The default data model includes the media and legal types above even when standard styles fall back to the `misc` driver. Preserve valid target classification independently of what today's importer can recover. An exhibition is not automatically an artwork, and a scene is not automatically a whole video. Never export a native conference event as `@conference`: that alias means `inproceedings`.

#### BibLaTeX fields

| Native source | BibLaTeX destination / policy |
| :--- | :--- |
| Citation key | Entry key |
| `I.title.value`, `I.title.short` | `title`, `shorttitle` |
| `P.title` | `journaltitle` for article; `booktitle` for a contribution |
| `P.title.short` | `shortjournal` for a journal; no general exact container-short-title equivalent |
| `M.title`, `M.volume-total` | `maintitle`, `volumes` for a selected volume within a set |
| `I.volume-total` for an explicitly identified whole multivolume set | `volumes` on the corresponding `mv*` record |
| `S.title` | `series` |
| `I.author` | `author` |
| `P.author` | `bookauthor` on contributions that support it |
| Selected `editor` list | `editor` |
| `I.affiliated` | Dedicated person fields or editor-role slots; see roles below |
| `I.date` | `date` at available precision |
| `C.title`, `C.date`, `C.location` | `eventtitle`, `eventdate`, `venue` on proceedings records |
| `B.edition` | `edition` |
| `I.volume` or `B.volume` | `volume` |
| `I.issue` or `B.issue` | Usually `number`; use `issue` only for a deliberately identified named issue |
| `I.chapter` | `chapter` |
| `I.page-range` | `pages` |
| `B.page-total` | `pagetotal` |
| `B.publisher.name` | `publisher` |
| `B.publisher.location` | `location` |
| `B.organization` | `institution` for reports/theses; `organization` for manuals, online resources, proceedings, etc. where appropriate |
| `I.genre` | `type` where the entry type supports it; otherwise a diagnosed fallback |
| `I.note` | `note` |
| Selected `B.note` on a distinct container | No automatic second note field |
| `I.abstract` | `abstract` |
| `I.url.value`, `I.url.date` | `url`, `urldate` |
| `serial-number.doi`, `.isbn`, `.issn`, `.isan`, `.ismn`, `.iswc` | Same-named fields |
| `serial-number.version` | `version` where supported |
| `serial-number.arxiv` | `eprint` + `eprinttype = {arxiv}` |
| `serial-number.pmid` | `eprint` + `eprinttype = {pubmed}` |
| `serial-number.serial` | `number` for report/patent/reference where appropriate; article identifiers can use `eid` |
| Other serial schemes, including `pmcid` | No generic field; apply the selected loss policy |
| `I.language` | `langid` via a supported identifier mapping; optional `language` for printable language information |
| `I.location` | `location` only where semantics match (for example patent jurisdiction); event locations use `venue` |
| `archive`, `archive-location`, `call-number`, `time-range`, `runtime` | No universal exact standard mapping |
| Selected `original` parent's title/date/publisher/location | `origtitle`, `origdate`, `origpublisher`, `origlocation` where semantically appropriate |

### Strict BibTeX mapping

#### BibTeX entry types

| Native item / selected context | Traditional BibTeX type | Qualification |
| :--- | :--- | :--- |
| `article` in `periodical` or `newspaper` | `article` | Requires a container title for `journaltitle` / `journal` |
| `article` in `proceedings` | `inproceedings` | Conference parent supplies additional event data |
| `article` in `blog` / `web`, or without an identifiable publication container | `misc` | A URL alone does not make every article an online resource |
| `chapter` in `book` | `incollection` for a separately titled contribution; `inbook` for a book portion identified by chapter/pages | Apply the different title rules below |
| `anthos` in `anthology` | `incollection` |  |
| `entry` in `reference` | `incollection` | Reference-work distinction lost in BibTeX |
| `chapter`, `anthos`, `entry` without a usable container | `misc` | Warn about missing relationship |
| `book` in `book` as an independently titled contained work | `incollection` | Requires explicit containment interpretation |
| Whole `book` | `book` | `mvbook` only for an explicitly identified whole multivolume set |
| `anthology` | `book` | `mvcollection` only for an explicit whole multivolume set |
| `reference` | `manual` for documentation, otherwise `book` | `mvreference` only for an explicit whole multivolume set; native type alone cannot choose manual |
| `proceedings` | `proceedings` | `mvproceedings` only for an explicit whole multivolume set |
| `periodical`, `newspaper` as the cited item | `misc` | A whole periodical/issue is not a journal article |
| `report` | `techreport` | Preserve genre as `type` where supported |
| `thesis` | `mastersthesis` or `phdthesis` only for a known degree; otherwise `misc` | Never assume a doctoral degree; BibLaTeX requires a suitable `type` |
| `manuscript` | `unpublished` | Note required for traditional BibTeX; optional for BibLaTeX |
| `patent` | `misc` | Patent classification and holder role lost in standard BibTeX |
| `web`, `blog`, `post`, `thread` | `misc` | For intrinsically online resources |
| `repository` | `misc` | Dataset import to repository is not an invertible type correspondence |
| `misc` | `misc` | No inferred booklet/software/set/xdata provenance |
| `misc` with an explicitly identified supplemental relationship | `incollection`, `article`, or `misc` as appropriate | Native `misc` plus a parent alone is insufficient to infer supplementation |
| `artwork` | `misc` | BibLaTeX default-model type; specific rendering depends on style |
| `case` | `misc` | BibLaTeX default-model type; specific rendering depends on style |
| `legislation` | `misc` | BibLaTeX default-model type; specific rendering depends on style |
| `performance` | `misc` | BibLaTeX default-model type; specific rendering depends on style |
| `video`, `audio`, `letter` | `misc` | BibLaTeX default-model types; specific rendering depends on style |
| `scene`, `conference`, `exhibition`, `original` as independently cited items | `misc` fallback | No exact default-model type; classify explicitly or acknowledge the loss |

Every `misc` fallback acknowledges a classification loss unless the native item already is `misc`. Never use the BibLaTeX types `online`, `report`, `thesis`, `collection`, `inreference`, `patent`, or `mv*` in this target. Native conference events cannot use the legacy `conference` alias, which means a proceedings paper.

#### BibTeX fields

| Native source | Traditional BibTeX destination / policy |
| :--- | :--- |
| Citation key | Entry key; validate syntax and uniqueness; report any renaming |
| `I.title.value`, `I.title.short` | `title`; short title has no standard field |
| `P.title` | `journal` for article; `booktitle` for incollection/inproceedings; see inbook exception |
| `P.title.short` | No standard equivalent |
| `M.title`, `M.volume-total` | No general exact equivalent; `series` only when a deliberate series/set interpretation is appropriate |
| `I.volume-total` for an explicitly identified whole multivolume set | No standard volume-total field; current import also drops `volumes` from standalone `mv*` records |
| `S.title` | `series` for entry types that support it |
| `I.author` | `author`, subject to inbook title/author semantics |
| `P.author` | No separate standard bookauthor field; traditional inbook uses the book's author/editor |
| Selected `editor` list | `editor` for supported types |
| `I.affiliated` | No general standard equivalent |
| `I.date` | `year`, `month`; day, season, and approximation have no standard separate fields |
| `C.title`, `C.date`, `C.location` | No standard event title/date fields; conference location can become `address` for proceedings types |
| `B.edition` | `edition`; render a numeric value as an appropriate ordinal string for traditional styles |
| `I.volume` or `B.volume` | `volume` where supported; resolve item/container duplication as described below |
| `I.issue` or `B.issue` | `number` where supported; conflicting volume/number combinations require resolution |
| `I.chapter` | `chapter` on inbook/incollection |
| `I.page-range` | `pages`; serialize ranges with `--`, separate disjoint parts with commas |
| `B.page-total` | No standard equivalent |
| `B.publisher.name` | `publisher` for supported types |
| `B.publisher.location` | `address`, except conference venue rules for proceedings |
| `B.organization` | `institution` for techreport; `school` for theses; `organization` for manual/proceedings types |
| `I.genre` | `type` only where supported; otherwise explicit note fallback or loss |
| `I.note` | `note` |
| Selected `B.note` on a distinct container | No automatic second note field; do not guess it was originally `howpublished` |
| `I.abstract` | No permitted abstract field; apply the selected loss policy |
| `I.url.value`, `I.url.date` | No permitted URL/access-date fields; explicit `howpublished`/`note` text fallback only under `text` |
| `serial-number.doi`, `.isbn`, `.issn`, `.isan`, `.ismn`, `.iswc` | No permitted identifier fields; apply the selected loss policy |
| `serial-number.version` | No permitted version field; apply the selected loss policy |
| `serial-number.arxiv` | No permitted eprint fields; apply the selected loss policy |
| `serial-number.pmid` | No permitted eprint fields; apply the selected loss policy |
| `serial-number.serial` | `number` only where its meaning and entry type fit; otherwise diagnosed loss |
| Other serial schemes, including `pmcid` | No generic field; apply the selected loss policy |
| `I.language` | No standard field |
| `I.location` | Context-dependent; do not assume every location is a publisher's address |
| `archive`, `archive-location`, `call-number`, `time-range`, `runtime` | No universal exact standard mapping |
| Selected `original` parent's title/date/publisher/location | No structured original-publication fields; apply the selected loss policy |

#### BibTeX field allowlist by entry type

For `bibtex-strict`, emit only the following ordinary fields, plus `key` and a validated `crossref`. Required fields are listed separately below. This is the traditional standard-style vocabulary in BibTeXing §3.1, not all fields accepted by a modern BibTeX package. The `conference` alias has the same fields as `inproceedings`.

| Entry type | Required and optional ordinary fields allowed in strict output |
| :--- | :--- |
| `article` | `author`, `title`, `journal`, `year`, `volume`, `number`, `pages`, `month`, `note` |
| `book` | `author`, `editor`, `title`, `publisher`, `year`, `volume`, `number`, `series`, `address`, `edition`, `month`, `note` |
| `booklet` | `title`, `author`, `howpublished`, `address`, `month`, `year`, `note` |
| `inbook` | `author`, `editor`, `title`, `chapter`, `pages`, `publisher`, `year`, `volume`, `number`, `series`, `type`, `address`, `edition`, `month`, `note` |
| `incollection` | `author`, `title`, `booktitle`, `publisher`, `year`, `editor`, `volume`, `number`, `series`, `type`, `chapter`, `pages`, `address`, `edition`, `month`, `note` |
| `inproceedings` | `author`, `title`, `booktitle`, `year`, `editor`, `volume`, `number`, `series`, `pages`, `address`, `month`, `organization`, `publisher`, `note` |
| `manual` | `title`, `author`, `organization`, `address`, `edition`, `month`, `year`, `note` |
| `mastersthesis`, `phdthesis` | `author`, `title`, `school`, `year`, `type`, `address`, `month`, `note` |
| `misc` | `author`, `title`, `howpublished`, `month`, `year`, `note` |
| `proceedings` | `title`, `year`, `editor`, `volume`, `number`, `series`, `address`, `month`, `organization`, `publisher`, `note` |
| `techreport` | `author`, `title`, `institution`, `year`, `type`, `number`, `address`, `month`, `note` |
| `unpublished` | `author`, `title`, `note`, `month`, `year` |

Fields required solely for standard crossref inheritance are the explicit exception described in the relationship section. Do not extend the allowlist just because the `.bib` grammar permits arbitrary field names. `annote`, `abstract`, `keywords`, `doi`, `url`, `isbn`, `issn`, and `urldate` are outside this strict standard-style contract. A custom `.bst` or package-specific exporter would need its own separately named target contract.

### Resolving competing values and node placement

Do not emit conflicting values into the same flat field. Examples requiring diagnostics are both arXiv and PubMed IDs competing for one `eprint`, an issue and serial competing for `number`, and two publishers or notes on different nodes. An article's serial number mapped to `eid` is valid BibLaTeX metadata but will not survive the current importer, which ignores `eid`.

Native `volume` and `issue` describe an item's position within its parent, so authored native entries can put them on I. The importer instead places them on P for contributions. Export must support both layouts: use the item's value when it identifies the selected publication's volume/issue, otherwise the selected publication's value. Equal duplicates can be emitted once; incompatible or semantically different values need a diagnostic or explicit selection. Do not require every native entry to reproduce the importer's physical layout. The same review applies when edition, publisher, identifiers, or other metadata appear on a different node from the import table: export according to the selected bibliographic relationship and report values that cannot be assigned unambiguously.

Do not split flattened publisher/organization names on commas. Emit a single literal value unless original list boundaries are available. If exporting actual BibLaTeX literal lists, separate elements with `and` and protect literal `and` inside an element. Similarly, a Unicode language identifier is not automatically a valid Babel/BibLaTeX `langid` spelling: map recognized identifiers and diagnose unsupported ones.

BibLaTeX `location` is context-sensitive: for a patent it can describe the jurisdiction rather than a publisher's location (§2.1.1). Today's importer nevertheless stores it as `publisher.location`. A future semantic exporter must account for that legacy placement when handling imported patents, and report conflicts with an independently populated native `location`.

For traditional proceedings, `address` can carry the conference location. If a publisher location is also present, report the collision or use an explicitly chosen text fallback (BibTeXing §2.2 item 10 discusses including publisher/organization address in those fields). Do not silently replace one location with the other. Re-import through today's Hayagriva importer will still put `address` into publisher location.

### Target requirements and title rules

Before writing a record, validate against the target vocabulary and report missing bibliographic data. Never invent authors, institutions, dates, publishers, or thesis degrees merely to satisfy a required-field check. The table summarizes BibTeXing §3.1; required-field warnings are separate from serialization errors.

| Standard type | Required fields |
| :--- | :--- |
| `article` | `author`, `title`, `journal`, `year` |
| `book` | `author` or `editor`; `title`, `publisher`, `year` |
| `booklet` | `title` |
| `inbook` | `author` or `editor`; `title`, `chapter` and/or `pages`, `publisher`, `year` |
| `incollection` | `author`, `title`, `booktitle`, `publisher`, `year` |
| `inproceedings` (alias `conference`) | `author`, `title`, `booktitle`, `year` |
| `manual` | `title` |
| `mastersthesis`, `phdthesis` | `author`, `title`, `school`, `year` |
| `misc` | None |
| `proceedings` | `title`, `year` |
| `techreport` | `author`, `title`, `institution`, `year` |
| `unpublished` | `author`, `title`, `note` |

BibLaTeX has different requirements (§2.1.1), with omissible-data qualifications in §2.3.2. Important differences for the proposed mappings include:

| BibLaTeX type / group | Listed requirements and differences from traditional BibTeX |
| :--- | :--- |
| `article` | `author`, `title`, `journaltitle`, year/date |
| `book`, `mvbook` | `author`, `title`, year/date; publisher is optional |
| `inbook`, `bookinbook` | `author`, `title`, `booktitle`, year/date; separate contribution title |
| `collection`, `mvcollection`, `reference`, `mvreference` | `editor`, `title`, year/date |
| `incollection`, `inreference` | `author`, `title`, `editor`, `booktitle`, year/date; see §2.3.2 for missing data |
| `inproceedings` | `author`, `title`, `booktitle`, year/date |
| `proceedings`, `mvproceedings` | `title`, year/date |
| `periodical` | `editor`, `title`, year/date; editor is omissible under §2.3.2 |
| `report`, `thesis` | `author`, `title`, `type`, `institution`, year/date |
| `patent` | `author`, `title`, `number`, year/date |
| `booklet`, `manual`, `dataset`, `misc` | `author`/`editor`, `title`, year/date; apply type-specific missing-data qualifications |
| `online` | `author`/`editor`, `title`, year/date, and DOI/eprint/URL; author/editor and year can be omitted under §2.3.2 |
| `software` | Uses the standard `misc` driver |
| `unpublished` | `author`, `title`, year/date; note is optional, unlike traditional BibTeX |

Thus an exporter should not impose the traditional BibTeX publisher requirement on a BibLaTeX book, or the traditional unpublished-note requirement on BibLaTeX. The BibLaTeX compatibility aliases for theses and technical reports supply default type terms; a canonical `thesis` or `report` export must select a suitable `type` explicitly or diagnose its absence.

Traditional `inbook` describes a portion of the **book**: its `title` and author/editor describe the book, with `chapter` and/or `pages` locating the portion. A separately titled native chapter should generally use `incollection`, with the chapter title in `title` and book title in `booktitle`. BibLaTeX `inbook` instead supports a self-contained, titled part and a separate `booktitle`/`bookauthor`. These choices can change the native type after re-import: a BibTeX `incollection` imports as `anthos`, even when exported from a native `chapter`.

Traditional styles allow `volume` **or** `number`, not both, for book/inbook/incollection/proceedings/inproceedings. Their supported optional fields also vary by type. Package extensions require a separately named target contract; they are not an option within either strict contract. In the strict BibTeX target, unsupported information can reach `note` or `howpublished` only under the explicit `text` loss policy; report that it has become unstructured text.

### Exporting names, roles, text, and dates

Use parsed name parts to generate Bib(La)TeX name syntax, with `and` between people, rather than copying a display-formatted citation. Protect corporate/literal names against person splitting. Check prefix and suffix behavior; native alias, comma-suffix, and nonstandard roles may require diagnostics. Never infer a truncated “and others” list from a missing person.

For BibLaTeX, export translator/annotator/commentator/holder/afterword/foreword/introduction through their dedicated fields. Export ordinary editors through `editor`, and compiler/founder/collaborator/organizer/director through available typed editor slots. Only four editor lists (`editor`, `editora`, `editorb`, `editorc`) exist in this mapping, so a work with more independent role groups needs a diagnostic or a deliberate extension. Producer/scriptwriter/performer conventions are style-specific. Do not serialize every native media role as if it had a portable standard field; composer, executive-producer, cinematography, illustrator, narrator, and unknown roles require explicit policy. Traditional BibTeX has no corresponding general role system beyond author/editor.

Escape TeX special characters in normal text, preserve intentional case protection with braces, and serialize math chunks as math. Existing parsed TeX and literal native text need different treatment to avoid double escaping. Preserve native short forms where supported; do not infer subtitle boundaries by splitting a title at a colon. Report native formatting or overrides that cannot be represented. A citation key needs its own syntax check; text escaping is not key escaping.

For BibLaTeX, emit available date precision, and use approximate-date syntax when appropriate. Handle native seasons only with a supported target encoding; the current importer does not preserve them. Traditional BibTeX should use `year` and a recognized month abbreviation (`jan`–`dec`) when available, diagnosing lost day/season/approximation precision. Neither target should receive invented dates. A simple exported date cannot restore an imported interval or distinguish uncertainty from approximation.

### Worked examples

These examples use ordinary strings and explicit native types. The YAML shows the relevant imported structure. The export blocks illustrate the proposed profiles; they are not output from an existing exporter.

#### Journal article

Input BibLaTeX:

```bibtex
@article{river,
  author = {Doe, Jane},
  title = {River measurements},
  journaltitle = {Journal of Rivers},
  date = {2024-05},
  volume = {12},
  number = {2},
  pages = {10--18},
  doi = {10.1234/example}
}
```

Implemented import, shown as native YAML:

```yaml
river:
  type: article
  author: "Doe, Jane"
  title: River measurements
  date: 2024-05
  page-range: 10-18
  serial-number:
    doi: 10.1234/example
  parent:
    type: periodical
    title: Journal of Rivers
    volume: 12
    issue: 2
```

Proposed BibLaTeX export can recover the mapped fields above. Proposed traditional BibTeX output uses `journal`, `year`, and `month`; the populated DOI requires explicit `omit` or `text` loss handling. Under the default `error` policy, export of this record must fail. The following illustrates `omit`, with a diagnostic for the DOI:

```bibtex
@article{river,
  author = {Doe, Jane},
  title = {River measurements},
  journal = {Journal of Rivers},
  year = {2024},
  month = may,
  volume = {12},
  number = {2},
  pages = {10--18}
}
```

#### Contribution with multivolume, series, and event metadata

Input BibLaTeX:

```bibtex
@inproceedings{flow,
  title = {Measuring flow},
  booktitle = {River Methods},
  maintitle = {Collected River Research},
  volume = {2},
  volumes = {3},
  series = {Hydrology Studies},
  eventtitle = {River Research Meeting},
  eventdate = {2024-05-10/2024-05-12},
  venue = {La Paz},
  publisher = {Example Press},
  location = {London}
}
```

Relevant implemented import:

```yaml
flow:
  type: article
  title: Measuring flow
  parent:
    - type: proceedings
      title: River Methods
      volume: 2
      publisher:
        name: Example Press
        location: London
      parent:
        type: proceedings
        title: Collected River Research
        volume-total: 3
        parent:
          type: proceedings
          title: Hydrology Studies
    - type: conference
      title: River Research Meeting
      date: 2024-05-12
      location: La Paz
```

A future exporter with the publication, MV, series, and conference relationships explicitly selected can flatten these nodes back to BibLaTeX fields, but only `eventdate = {2024-05-12}` survives. The original event interval is already lost. Traditional BibTeX cannot separately express `maintitle`, `volumes`, event title/date, and both locations with standard dedicated fields. Neither profile should invent the missing author or publication date; these are intentionally incomplete example data, requiring export validation diagnostics.

## Compatibility and future validation

There are three different expectations to check when implementing export:

- **Import accuracy:** tests should pin the physical destinations, aliases, overwrite order, ignored values, and errors described above. Existing tests in `interop.rs` cover examples such as PMID, volume text, roles, language, default genres, chapter numbers, prefixes, and serial numbers; they are not exhaustive coverage of this document.
- **Target validity:** parse serialized output with an independent reader where possible, check the chosen profile's required and optional fields, and check bibliography rendering with the target style. Passing Hayagriva's importer alone does not demonstrate traditional BibTeX compatibility.
- **Round-trip expectations:** compare only explicitly supported semantic fields. Expect diagnostics for collapsed source types (`manual`/`reference`, `booklet`/`software`/`misc`), lost fields, ambiguous parent roles, conflicting flat fields, date intervals, and target-specific classification changes. Exact byte equality or full native-entry equality is not a general contract.

Useful future fixtures include every entry-type row; all three aliases (`conference`, `electronic`, `www`); each field alias; MV triggering with and without `maintitle`/`volume`; a standalone `mvbook`; simultaneous event/series/MV parents; `issue` versus `number`; `journaltitle` versus `issuetitle`; each note precedence case; invalid/literal dates and URLs; unsupported eprint services; unknown languages and roles; multiple institutions/publishers; literal names; and every traditional BibTeX required-field group. Include cases that are valid for the target but intentionally fail to round-trip through today's importer.

The strict exporters also need independent acceptance cases:

| Input / choice | Strict BibLaTeX expectation | Strict BibTeX expectation |
| :--- | :--- | :--- |
| Populated native DOI | `doi` allowed | `error` fails; `omit` drops with a diagnostic; `text` can retain it in an allowed note |
| BibLaTeX keywords previously imported into native data | Do not reconstruct lost keywords | Do not reconstruct lost keywords |
| Explicit external keywords supplied to export | Validate and emit `keywords` | Reject under `error`, or explicitly omit with a diagnostic |
| Unknown YAML custom field supplied before native parsing | Not retained by the native model; export cannot recover it | Same limitation |
| Explicit external arbitrary field | Reject unless declared in a separately selected extended data model | Reject in the strict target |
| Article with one unambiguous publication parent | Flatten to appropriate container fields by default | Flatten to permitted container fields by default |
| Publication crossref requested | Generate unique keys and check Biber inheritance semantics | Generate unique keys, order parent after children, and supply fields needed for traditional inheritance |
| Conference parent alongside proceedings parent | Map event fields separately from the publication crossref | Do not create a second crossref or emit event fields; apply the loss policy to unrepresentable event data |
| Native video | `video` is a valid default-model classification, even if re-import currently loses it | Classification fallback needs explicit loss acceptance |
| Ambiguous series versus MV parent | Fail pending explicit selection under `error` | Fail pending explicit selection under `error` |
