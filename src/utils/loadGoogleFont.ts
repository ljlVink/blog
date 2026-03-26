import { readFile } from "node:fs/promises";

const LOCAL_FONTS = {
  regular: "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
  bold: "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
} as const;

async function loadGoogleFonts(
  _text: string
): Promise<
  Array<{ name: string; data: ArrayBuffer; weight: number; style: string }>
> {
  const fontsConfig = [
    {
      name: "DejaVu Sans",
      path: LOCAL_FONTS.regular,
      weight: 400,
      style: "normal",
    },
    {
      name: "DejaVu Sans",
      path: LOCAL_FONTS.bold,
      weight: 700,
      style: "bold",
    },
  ];

  const fonts = await Promise.all(
    fontsConfig.map(async ({ name, path, weight, style }) => {
      const data = await readFile(path);
      return {
        name,
        data: data.buffer.slice(
          data.byteOffset,
          data.byteOffset + data.byteLength
        ) as ArrayBuffer,
        weight,
        style,
      };
    })
  );

  return fonts;
}

export default loadGoogleFonts;
