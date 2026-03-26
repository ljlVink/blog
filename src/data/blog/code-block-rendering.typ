#import "/typ/templates/blog.typ": *

#show: main.with(
  title: "Typst Code Block Rendering Test",
  author: "Vink",
  description: "A focused Typst post for validating code block layout, spacing, and syntax rendering in Astro.",
  pubDatetime: "2026-03-25T12:00:00Z",
  tags: ("typst", "code", "test"),
  featured: false,
  draft: false,
)

== Linear algebra

$
A x = b,
A = mat(
  2, -1, 0;
  -1, 2, -1;
  0, -1, 2
)
$

For a diagonally dominant matrix like this one, iterative solvers converge
reliably under common conditions.

= Code Block Rendering Test

This page exists to verify the updated Typst code block container on the Astro
side. It checks language labels, horizontal overflow, copy-button placement,
and mixed language rendering in one place.

== TypeScript

```ts
type ArticleMeta = {
  title: string;
  tags: string[];
  updatedAt?: string;
};

export function summarize(meta: ArticleMeta) {
  return `${meta.title} (${meta.tags.join(", ")})`;
}
```

== Bash

```bash
pnpm install
pnpm astro check
pnpm astro build
```

== Rust

```rust
fn collect_visible_posts(posts: Vec<&str>) -> Vec<&str> {
    posts
        .into_iter()
        .filter(|post| !post.ends_with(".draft"))
        .collect()
}
```

== Long Line Overflow

```txt
https://example.com/articles/typst/code/rendering/check?theme=light&mode=overflow&line=this-is-a-very-long-line-used-to-confirm-that-horizontal-scrolling-stays-contained-inside-the-code-card
```

== Plain Text

```text
code block spacing should stay stable even without strong syntax colors.
```
