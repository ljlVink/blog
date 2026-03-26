import type { AstroIntegration } from "astro";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path/posix";
import { defaultTarget, detectTarget } from "astro-typst/dist/lib/prelude.js";
import { renderToHTMLish } from "astro-typst/dist/lib/typst.js";
import { setAstroConfig, setConfig } from "astro-typst/dist/lib/store.js";

type TypstTarget = "html" | "svg";

type LocalTypstConfig = {
  options?: Record<string, unknown>;
  target?: string | ((id: string) => string | Promise<string>);
  htmlMode?: "text";
  emitSvg?: boolean;
  emitSvgDir?: string;
  fontArgs?: unknown[];
};

function getRenderer() {
  return {
    name: "astro:jsx",
    serverEntrypoint: "astro-typst/dist/renderer/index.js",
  };
}

function isTypstFile(id: string) {
  return /\.typ(\?(html|svg|html-text|text))?$/.test(id);
}

function extractOpts(id: string) {
  const q = id.lastIndexOf("?");
  if (q === -1) {
    return { path: id, opts: "" };
  }

  return {
    path: id.slice(0, q),
    opts: id.slice(q + 1),
  };
}

function injectRenderTarget(code: string, renderTarget: TypstTarget) {
  if (!code.includes("#show: main.with(") || code.includes("renderTarget:")) {
    return code;
  }

  return code.replace(
    /#show:\s*main\.with\(\s*/m,
    `#show: main.with(\n  renderTarget: "${renderTarget}",\n  `
  );
}

function createTypstModuleCode(html: string, frontmatter: Record<string, unknown>, mainFilePath: string) {
  return `
import { createComponent, render, unescapeHTML } from "astro/runtime/server/index.js";
import { readFileSync } from "node:fs";
export const name = "TypstComponent";
export const html = ${JSON.stringify(html)};
export const frontmatter = ${JSON.stringify(frontmatter)};
export const file = ${JSON.stringify(mainFilePath)};
export const url = ${JSON.stringify(pathToFileURL(mainFilePath))};
export function rawContent() {
  return readFileSync(file, "utf-8");
}
export function compiledContent() {
  return ${JSON.stringify(html)};
}
export function getHeadings() {
  return undefined;
}
export const Content = createComponent(async (_result, _props, _slots) => {
  return render\`\${unescapeHTML(compiledContent())}\`;
});
export default Content;
`;
}

function vitePluginLocalTypst(config: LocalTypstConfig, astroBase = "/") {
  return {
    name: "vite-plugin-local-typst",
    enforce: "pre" as const,
    async transform(code: string, id: string) {
      if (!isTypstFile(id)) {
        return;
      }

      const { path: mainFilePath, opts } = extractOpts(id);
      let isHtml = false;

      if (opts.includes("svg")) {
        isHtml = false;
      } else if (opts.includes("html") || opts.includes("text")) {
        isHtml = true;
      } else {
        isHtml = (await detectTarget(mainFilePath, config.target ?? defaultTarget)) === "html";
      }

      const renderTarget: TypstTarget = isHtml ? "html" : "svg";
      const source = {
        mainFileContent: injectRenderTarget(code, renderTarget),
        body: true as const,
      };

      let { html, getFrontmatter } = await renderToHTMLish(
        source,
        config.options,
        isHtml
      );

      if (config.emitSvg && !isHtml) {
        const contentHash = crypto.randomUUID().slice(0, 8);
        const fileName = `typst-${contentHash}.svg`;
        const emitSvgDir = config.emitSvgDir ?? "typst";
        const publicUrl = path.join(astroBase, emitSvgDir, fileName);

        if (import.meta.env.PROD) {
          this.emitFile({
            type: "asset",
            fileName: path.join(emitSvgDir, fileName),
            source: Buffer.from(html, "utf-8"),
          });
          html = `<img src="${publicUrl}" />`;
        } else {
          html = `<img src="data:image/svg+xml;base64,${Buffer.from(html, "utf-8").toString("base64")}" />`;
        }
      }

      return {
        code: createTypstModuleCode(html, getFrontmatter?.() || {}, mainFilePath),
        map: null,
      };
    },
  };
}

export function localTypst(config: LocalTypstConfig = {}): AstroIntegration {
  const mergedConfig: LocalTypstConfig = {
    options: {
      remPx: 16,
      ...(config.options || {}),
    },
    target: config.target ?? defaultTarget,
    htmlMode: "text",
    emitSvg: config.emitSvg,
    emitSvgDir: config.emitSvgDir,
    fontArgs: config.fontArgs,
  };

  return {
    name: "local-typst",
    hooks: {
      "astro:config:setup": options => {
        setConfig(mergedConfig as never);
        setAstroConfig(options.config);

        options.addRenderer(getRenderer());
        options.addPageExtension(".typ");
        options.addContentEntryType({
          extensions: [".typ"],
          async getEntryInfo({ fileUrl, contents }) {
            const mainFilePath = fileURLToPath(fileUrl);
            const isHtml =
              (await detectTarget(fileUrl.pathname, mergedConfig.target ?? defaultTarget)) === "html";

            const { getFrontmatter } = await renderToHTMLish(
              {
                mainFilePath,
              },
              mergedConfig.options,
              isHtml
            );

            const frontmatter = getFrontmatter?.() || {};

            return {
              data: frontmatter,
              body: contents,
              // @ts-expect-error astro content slug typing is loose here
              slug: frontmatter.slug,
              rawData: contents,
            };
          },
          handlePropagation: false,
          contentModuleTypes: `
declare module 'astro:content' {
  interface Render {
    '.typ': Promise<{
      Content: import('astro').MarkdownInstance<{}>['Content'];
    }>;
  }
}
`,
        });

        options.updateConfig({
          vite: {
            build: {
              rollupOptions: {
                external: ["@myriaddreamin/typst-ts-node-compiler"],
              },
            },
            plugins: [vitePluginLocalTypst(mergedConfig, options.config.base ?? "/")],
          },
        });
      },
      "astro:config:done": ({ config, injectTypes }) => {
        injectTypes({
          filename: "local-typst.d.ts",
          content: `declare module "*.typ" {
  const component: () => any;
  export default component;
}`,
        });
        setAstroConfig(config);
      },
    },
  };
}
