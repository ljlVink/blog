export const SITE = {
  website: "https://blog.ljlvink.top/", // replace this with your deployed domain
  author: "Vink",
  profile: "https://github.com/ljlVink",
  desc: "ljlVink's blog",
  title: "ljlVink's Blog",
  ogImage: "astropaper-og.jpg",
  lightAndDarkMode: true,
  postPerIndex: 4,
  postPerPage: 4,
  scheduledPostMargin: 15 * 60 * 1000, // 15 minutes
  showArchives: true,
  showBackButton: true, // show back button in post detail
  editPost: {
    enabled: true,
    text: "Edit page",
    url: "https://github.com/ljlVink/blog/edit/main/",
  },
  dynamicOgImage: true,
  dir: "ltr", // "rtl" | "auto"
  lang: "en", // html lang code. Set this empty and default will be "en"
  timezone: "Asia/Shanghai", // Default global timezone (IANA format) https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
} as const;

export const GISCUS = {
  enabled: false,
  repo: "",
  repoId: "",
  category: "",
  categoryId: "",
  mapping: "pathname",
  strict: "0",
  reactionsEnabled: "1",
  emitMetadata: "0",
  inputPosition: "top",
  lang: "en",
  loading: "lazy",
  theme: {
    light: "light",
    dark: "dark_dimmed",
  },
} as const;
