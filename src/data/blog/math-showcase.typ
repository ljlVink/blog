#import "/typ/templates/blog.typ": *

#show: main.with(
  title: "Math Showcase with Typst SVG",
  author: "Vink",
  description: "A compact demo of equations, layout, and technical writing with Typst rendered as SVG inside Astro.",
  pubDatetime: "2026-03-26T00:00:00Z",
  tags: ("typst", "astro", "svg"),
  featured: true,
  draft: false,
)

= A compact math-heavy post

This entry intentionally uses the `.svg.typ` suffix, so the Astro integration
keeps Typst's SVG output. That makes it a good fit for dense equations or
layout-sensitive notes where vector fidelity matters more than native HTML flow.

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

== A short derivation

Define $f(x) = x^3 - 3x + 1$.

Its first derivative is $f'(x) = 3x^2 - 3$.

Its second derivative is $f''(x) = 6x$.

Critical points appear where $f'(x) = 0$, which gives $x = -1$ or $x = 1$.
This is the kind of article where SVG output can still be worth keeping around.
