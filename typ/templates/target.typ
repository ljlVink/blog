// Keep target detection frontmatter-safe.
// `astro-typst` does not expose `target` while extracting metadata, so these
// helpers must avoid touching undeclared variables during import.
#let sys-is-html-target = ("target" in dictionary(std))
#let sys-is-web-target = sys-is-html-target
