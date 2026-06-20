# Bib(La)TeX to Hayagriva Mapping Reference

This document serves as a complete mapping reference for how Hayagriva converts Bib(La)TeX bibliographies to Hayagriva's native YAML-backed data model. It outlines how entry types, fields, and person roles map, and how parent hierarchies are dynamically constructed during the unidirectional mapping.

---

## 1. Entry Types Mapping

Bib(La)TeX entry types are mapped to a Hayagriva `EntryType` and a default `parent` type. Some entry types support **Multi-Volume Expansion** (if both `maintitle` and `volume` fields are present).

| Bib(La)TeX Entry Type | Hayagriva Entry Type | Parent Entry Type | Multi-Volume Parent? | Notes |
| :--- | :--- | :--- | :--- | :--- |
| `@article` | `Article` | `Periodical` | No | |
| `@book` | `Book` | *None* | **Yes** | |
| `@booklet` | `Misc` | *None* | No | |
| `@inbook` | `Chapter` | `Book` | **Yes** | |
| `@incollection` | `Anthos` | `Anthology` | **Yes** | |
| `@inproceedings` | `Article` | `Proceedings` | **Yes** | |
| `@manual` | `Reference` | *None* | No | |
| `@mastersthesis` | `Thesis` | *None* | No | Default genre: `"Master's thesis"` |
| `@phdthesis` | `Thesis` | *None* | No | Default genre: `"Doctoral dissertation"` |
| `@thesis` | `Thesis` | *None* | No | |
| `@misc` | `Misc` | *None* | No | |
| `@proceedings` | `Proceedings` | *None* | **Yes** | |
| `@report` | `Report` | *None* | **Yes** | |
| `@techreport` | `Report` | *None* | **Yes** | Default genre: `"technical report"` |
| `@unpublished` | `Manuscript` | *None* | **Yes** | |
| `@mvbook` | `Book` | *None* | No | |
| `@bookinbook` | `Book` | `Book` | **Yes** | |
| `@suppbook` | `Misc` | `Book` | **Yes** | |
| `@periodical` | `Periodical` | *None* | **Yes** | |
| `@suppperiodical` | `Misc` | `Periodical` | **Yes** | |
| `@collection` | `Anthology` | *None* | **Yes** | |
| `@suppcollection` | `Misc` | `Anthology` | **Yes** | |
| `@reference` | `Reference` | *None* | **Yes** | |
| `@mvreference` | `Reference` | *None* | No | |
| `@inreference` | `Entry` | `Reference` | **Yes** | |
| `@mvproceedings` | `Proceedings` | *None* | No | |
| `@mvcollection` | `Anthology` | *None* | No | |
| `@patent` | `Patent` | *None* | No | |
| `@online` | `Web` | *None* | No | |
| `@software` | `Misc` | *None* | No | |
| `@dataset` | `Repository` | *None* | No | |
| `@set` | `Misc` | *None* | No | |
| `@xdata` | `Misc` | *None* | No | Handled by parser for field inheritance |
| *Unknown types* | `Misc` | *None* | No | |

---

## 2. Parent Hierarchy & Dynamically Injected Parents

Hayagriva prevents field bloat by structuring hierarchical information (e.g. journal title, conference location, series name) using **parent entries**. Up to four parents can be dynamically constructed and linked to a cited item (`item`):

### A. Standard Parent

If a `Parent Entry Type` is defined in the table above:

- A parent entry is created with that type and added to `item.parents`.
- Parent-level fields (like `journaltitle`, `booktitle`, `publisher`, `location`, `organization`/`institution`, `edition`, `volume`, `page-total`, `howpublished`) are automatically set on this parent instead of the root item.

### B. Multi-Volume Parent (MV Parent)

If **Multi-Volume Parent?** is marked **Yes** in the table above, AND both `maintitle` and `volume` fields are present on the Bib(La)TeX entry:

1. **If a Standard Parent exists** (e.g. `Book` parent for `@inbook` / `Chapter` item):
   - A parent of the *same type* as the Standard Parent is created and linked as a parent of the Standard Parent.
   - **Hierarchy**: `item` (e.g., `Chapter`) $\to$ `parent` (e.g., `Book`) $\to$ `mv_parent` (e.g., `Book`).
2. **If NO Standard Parent exists** (e.g. for `@book` / `Book` item):
   - A parent of the *same type* as the item is created and linked directly to the item.
   - **Hierarchy**: `item` (e.g., `Book`) $\to$ `parent` (acting as `mv_parent`).

The following fields map to the `mv_parent`:

- `maintitle` $\to$ `mv_parent.title`
- `volumes` $\to$ `mv_parent.volume-total`

### C. Conference Parent

If the entry type is `@proceedings`, `@mvproceedings`, or `@inproceedings`, AND any of the fields `eventdate`, `eventtitle`, or `venue` are present:

- A new parent entry of type `Conference` is created and added to `item.parents`.
- `eventtitle` $\to$ `conference.title`
- `eventdate` $\to$ `conference.date`
- `venue` $\to$ `conference.location`

### D. Series Parent

If the `series` field is present, a new parent entry representing the series is created (with the same type as the entry it attaches to) and its `title` is set to the series name. It is attached to the highest level possible:

- If an `mv_parent` exists, the series parent is added to `mv_parent.parents`.
- Else, if a standard `book`/`parent` exists, the series parent is added to `parent.parents`.
- Otherwise, the series parent is added to `item.parents`.

---

## 3. Field Mapping

The following table shows how Bib(La)TeX fields map to Hayagriva fields and which entry in the hierarchy they are applied to.

| Bib(La)TeX Field | Hayagriva Field | Applied to Entry | Notes / Conversion Logic |
| :--- | :--- | :--- | :--- |
| `author` | `author` | `item` | List of `Person`s |
| `bookauthor` | `author` | `parent` | Only if a standard parent is created |
| `editor` / `editor[a-c]` | `editor` / `affiliated` | `item` | Mapped to `editors` or `affiliated` list depending on `editortype` (see Role Mapping) |
| `holder` | `affiliated` | `item` | Role: `holder` |
| `annotator` | `affiliated` | `item` | Role: `annotator` |
| `commentator` | `affiliated` | `item` | Role: `commentator` |
| `translator` | `affiliated` | `item` | Role: `translator` |
| `afterword` | `affiliated` | `item` | Role: `afterword` |
| `foreword` | `affiliated` | `item` | Role: `foreword` |
| `introduction` | `affiliated` | `item` | Role: `introduction` |
| `title` | `title.value` | `item` | FormatString |
| `shorttitle` | `title.short` | `item` | Optional short title |
| `maintitle` | `title` | `mv_parent` | Sets the title of the multi-volume parent entry |
| `journaltitle` | `title` | `parent` | For `@article` entries; sets the `Periodical` parent's title |
| `booktitle` | `title` | `parent` | For other types with parents; sets parent title |
| `eventtitle` | `title` | `conference` | Sets title of the injected `Conference` parent |
| `eventdate` | `date` | `conference` | Sets date of the injected `Conference` parent |
| `venue` | `location` | `conference` | Sets location of the injected `Conference` parent |
| `date` | `date` | `item` | `Date` (uncertain/approximate flags are mapped) |
| `edition` | `edition` | `parent` or `item` | Applied to `parent` if exists, otherwise `item` |
| `issue` | `issue` | `parent` or `item` | For `@article`/`@proceedings`; sets `parent.issue` if exists, else `item.issue` |
| `issuetitle` | `title` | `parent` or `item` | For `@article`/`@proceedings`; sets `parent.title` if exists, else `item.title` |
| `number` | `issue` / `serial-number` | `parent` or `item` | - If `parent` exists: `parent.issue`<br>- Else if type is `Report`, `Patent`, `Entry`, or `Reference`: `item.serial-number` (key `"serial"`) <br>- Otherwise: `item.issue` |
| `volume` | `volume` | `parent` or `item` | Applied to `parent` if exists, otherwise `item` |
| `volumes` | `volume-total` | `mv_parent` | Applied to the multi-volume parent |
| `version` | `serial-number` | `item` | Key: `"version"` |
| `doi` | `serial-number` | `item` | Key: `"doi"` |
| `isbn` | `serial-number` | `item` | Key: `"isbn"` (as verbatim string) |
| `issn` | `serial-number` | `item` | Key: `"issn"` (as verbatim string) |
| `eprint` | `serial-number` | `item` | Mapped depending on `eprinttype`:<br>- `"arxiv"` $\to$ Key: `"arxiv"` <br>- `"pubmed"` $\to$ Key: `"pmid"` |
| `isan` | `serial-number` | `item` | Key: `"isan"` (as verbatim string) |
| `ismn` | `serial-number` | `item` | Key: `"ismn"` (as verbatim string) |
| `iswc` | `serial-number` | `item` | Key: `"iswc"` (as verbatim string) |
| `url` | `url.value` | `item` | Canonical URL |
| `urldate` | `url.date` | `item` | Visited/access date |
| `publisher` | `publisher.name` | `parent` or `item` | Comma-separated list; applied to `parent` if exists, else `item` |
| `location` | `publisher.location`| `parent` or `item` | Location of publisher; applied to `parent` if exists, else `item` |
| `organization` | `organization` | `parent` or `item` | Comma-separated list; applied to `parent` if exists, else `item` |
| `institution` | `organization` | `parent` or `item` | Fallback if `organization` is not present |
| `howpublished` | `note` | `parent` or `item` | Applied to `parent` if exists, else `item` |
| `pages` | `page-range` | `item` | List of page ranges (`SinglePage` or `Range`) |
| `pagetotal` | `page-total` | `parent` or `item` | Applied to `parent` if exists, else `item` |
| `note` | `note` | `item` | |
| `annotation` | `note` | `item` | Fallback for `note` if empty |
| `addendum` | `note` | `item` | Fallback for `note` if empty |
| `abstract` | `abstract` | `item` | |
| `type` | `genre` | `item` | Maps directly to genre, or defaults based on entry type:<br>- `@mastersthesis` $\to$ `"Master's thesis"`<br>- `@phdthesis` $\to$ `"Doctoral dissertation"`<br>- `@techreport` $\to$ `"technical report"` |
| `series` | `title` | `series` (parent) | Injected parent representing series (see section 2.D) |
| `chapter` | `chapter` | `item` | Chapter or section number |
| `language` / `langid` | `language` | `item` | BCP-47 identifier (first parsed lang or fallback to `langid`) |

---

## 4. Editor Roles Mapping

The `editor`, `editora`, `editorb`, and `editorc` lists specify editor roles via `editortype`, `editoratype`, `editorbtype`, and `editorctype`. These are mapped to either Hayagriva's root `editors` field or the `affiliated` field with a specific `PersonRole`.

| BibLaTeX Role / Editor Type | Hayagriva Field / Role | Notes |
| :--- | :--- | :--- |
| `editor` | `editors` field | Primary editor |
| `compiler` | `affiliated` (role: `compiler`) | |
| `founder` | `affiliated` (role: `founder`) | |
| `continuator` | `editors` field | Maps to None (standard editors) |
| `redactor` | `editors` field | Maps to None (standard editors) |
| `reviser` | `editors` field | Maps to None (standard editors) |
| `collaborator` | `affiliated` (role: `collaborator`) | |
| `organizer` | `affiliated` (role: `organizer`) | |
| `director` | `affiliated` (role: `director`) | |
| `producer` | `affiliated` (role: `producer`) | For unrecognized types |
| `scriptwriter` | `affiliated` (role: `writer`) | Standard Zotero scriptwriter export |
| `writer` | `affiliated` (role: `writer`) | Standard APA video writer role; only if entry type is `video` |
| `none` | `affiliated` (role: `cast-member`) | Standard Chicago video/music performer role; only if entry type is `video` or `music` |
| *Other unknown roles* | `affiliated` (role: `unknown(<role_string>)`) | Retained as unknown role |

---

## 5. Bidirectional Mapping Notes

> [!NOTE]
> Currently, the mapping is unidirectional: **Bib(La)TeX $\to$ Hayagriva**. A bidirectional mapping is planned. The parent-hierarchy logic will need careful inverse mapping to reconstruct flat BibLaTeX entries from hierarchical Hayagriva entry graphs.
