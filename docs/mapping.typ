= Conversion mapping between Hayagriva and BiB(La)TeX

== BiBTeX to Hayagriva

== BiBLaTeX to Hayagriva

== Hayagriva to BiBTeX

== Hayagriva to BiBLaTeX

=== Type mapping

#table(
  columns: 3,
  table.header([Hayagriva], [BiBLaTeX], [Notes]),
  [Article], `@article`, [],
  [Book], `@book`, [],
  [Chapter], `@incollection`, [`@inbook` can be also be used only if the author is the same as the book author.],
  [Anthology], `@collection`, [A book with a distinct editor/compiler.],
  [Conference], `@inproceedings`, [PApers within a conference],
  [Entry], [], [],
  [Anthos], [], [],
  [Report], `@report`, [],
  [Thesis], `@thesis`, [],
  [Web], `@online`, [],
  [Scene], [], [],
  [Artwork], [], [],
  [Patent], `@patent`, [],
  [Case], [], [],
  [Newspaper], `@article`, [],
  [Legislation], [], [],
  [Manuscript], [], [],
  [Original], [], [],
  [Post], [], [],
  [Misc], `@misc`, [],
  [Performance], [], [],
  [Periodical], `@periodical`, [],
  [Proceedings], [], [],
  [Blog], `@online`, [],
  [Reference], `@reference`, [],
  [Repository], [], [],
  [Thread], [], [],
  [Video], [], [],
  [Audio], [], [],
  [Exhibition], [], [],
)

=== Field mapping

#table(
  columns: 3,
  table.header([Hayagriva], [BiBLaTeX], [Notes]),
  [title], [title], [],
  [author], [author], [],
)
