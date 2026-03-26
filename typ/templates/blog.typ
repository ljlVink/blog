#let plain-text(content) = str(content)

// Main template function for blog posts
#let main(
  title: "Untitled",
  author: "Vink",
  description: "",
  pubDatetime: "1970-01-01T00:00:00Z",
  tags: (),
  featured: false,
  draft: false,
  renderTarget: "query",
  body,
) = {
  show: it => if renderTarget == "html" {
    // Render math equations via html.frame so the page stays HTML-first while
    // formulas keep Typst's vector output.
    show math.equation.where(block: true): eq => {
      html.elem(
        "div",
        html.frame(eq),
        attrs: (class: "block-equation", role: "math"),
      )
    }
    show math.equation.where(block: false): eq => {
      html.elem(
        "span",
        html.frame(eq),
        attrs: (class: "inline-equation", role: "math"),
      )
    }

    show figure: fig => html.elem("div", fig, attrs: (
      ..if "label" in fig.fields() and fig.label != none {
        (id: str(fig.label))
      },
      class: "figure-container",
    ))

    show raw.where(block: true): raw_block => {
      html.elem("div", raw_block, attrs: (class: "code-block"))
    }

    show link: link_node => {
      html.elem("a", link_node, attrs: (href: link_node.dest))
    }

    set page(width: auto, height: auto, margin: 1.2em)
    set par(justify: true, leading: 0.75em)
    set text(size: 11pt)

    it
  } else {
    set page(width: auto, height: auto, margin: 1.2em)
    set par(justify: true, leading: 0.75em)
    set text(size: 11pt)

    it
  }

  // Return content with metadata
  [
    #metadata((
      title: title,
      author: author,
      description: if type(description) == content {
        plain-text(description)
      } else {
        description
      },
      pubDatetime: pubDatetime,
      tags: tags,
      featured: featured,
      draft: draft,
    ))<frontmatter>
    
    #body
  ]
}
