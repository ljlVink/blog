#import "/typ/templates/blog.typ": *

#show: main.with(
  title: "Getting Started with Typst in Astro",
  author: "Vink",
  description: "A first Typst post rendered as semantic HTML inside an AstroPaper blog.",
  pubDatetime: "2026-03-25T00:00:00Z",
  tags: ("typst", "astro", "svg"),
  featured: true,
  draft: true,
)

= Typst on the Web

This post lives in a `.typ` file, but it flows through Astro's content
collections exactly like Markdown. The difference is in the final rendering:
the article body is compiled to SVG, which keeps formulas and layout sharp at
any zoom level.

== Why this setup is useful

- One content pipeline can mix Markdown and Typst posts.
- Equations stay crisp because they are vector graphics.
- The surrounding page still gets AstroPaper's metadata, tags, search, and SEO.

== A quick equation

$
sum_(k = 1)^n k = n(n + 1) / 2
$

```cpp
//hello cpp render
#include <stdio.h>
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```
== Delivery notes

#table(
  columns: 2,
  [Layer], [Role],
  [Astro], [Static site generation, routes, RSS, sitemap, and layout chrome],
  [astro-typst], [Compiles Typst source and exposes frontmatter to Astro],
  [Pagefind], [Indexes hidden plain text extracted from the `.typ` source],
)

The resulting page behaves like a regular blog post, while keeping Typst as the
authoring format behind the scenes.
