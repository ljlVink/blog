import { defineConfig, envField } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import sitemap from "@astrojs/sitemap";
import remarkToc from "remark-toc";
import remarkCollapse from "remark-collapse";
import {
  transformerNotationDiff,
  transformerNotationHighlight,
  transformerNotationWordHighlight,
} from "@shikijs/transformers";
import { localTypst } from "./src/integrations/localTypst";
import { transformerFileName } from "./src/utils/transformers/fileName";
import { SITE } from "./src/config";

function resolveTypstTarget(id: string) {
  if (id.endsWith(".svg.typ") || id.includes("/svg/")) {
    return "svg";
  }
  return "html";
}

// https://astro.build/config
export default defineConfig({
  site: SITE.website,
  integrations: [
    localTypst({
      target: resolveTypstTarget,
      htmlMode: "text",
      options: {
        remPx: 14,
        cheerio: {
          postprocess: $ => {
            const svg = $("svg");
            svg.attr("width", "100%");
            svg.attr("preserveAspectRatio", "xMinYMin meet");
            svg.css("display", "block");
            svg.css("height", "auto");
            return $;
          },
        },
      },
      fontArgs: [{ fontPaths: ["./typ/fonts"] }],
    }),
    sitemap({
      filter: page => SITE.showArchives || !page.endsWith("/archives"),
    }),
  ],
  markdown: {
    remarkPlugins: [remarkToc, [remarkCollapse, { test: "Table of contents" }]],
    shikiConfig: {
      // For more themes, visit https://shiki.style/themes
      themes: { light: "min-light", dark: "night-owl" },
      defaultColor: false,
      wrap: false,
      transformers: [
        transformerFileName({ style: "v2", hideDot: false }),
        transformerNotationHighlight(),
        transformerNotationWordHighlight(),
        transformerNotationDiff({ matchAlgorithm: "v3" }),
      ],
    },
  },
  vite: {
    // eslint-disable-next-line
    // @ts-ignore
    // This will be fixed in Astro 6 with Vite 7 support
    // See: https://github.com/withastro/astro/issues/14030
    plugins: [tailwindcss()],
    optimizeDeps: {
      exclude: ["@resvg/resvg-js"],
    },
  },
  image: {
    responsiveStyles: true,
    layout: "constrained",
  },
  env: {
    schema: {
      PUBLIC_GOOGLE_SITE_VERIFICATION: envField.string({
        access: "public",
        context: "client",
        optional: true,
      }),
    },
  },
  experimental: {
    preserveScriptOrder: true,
  },
});
