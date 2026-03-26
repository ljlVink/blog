const METADATA_BLOCK_PATTERN = /#metadata\(([\s\S]*?)\)<frontmatter>\s*/g;
const COMMENT_PATTERN = /\/\/.*$/gm;
const BLOCK_COMMAND_PATTERN =
  /#(?:set|show|import|include|let|context)\b[^\n]*(?:\n|$)/g;
const INLINE_CALL_WITH_BODY_PATTERN =
  /#(?:link|figure|quote|box|align|stack|grid|enum|list|terms|par)\([^)]*\)\[([\s\S]*?)\]/g;
const INLINE_CALL_PATTERN = /#\w+\([^)]*\)/g;
const LABEL_PATTERN = /<[^>\n]+>/g;
const HEADING_PATTERN = /^=+\s*/gm;
const RAW_MARKUP_PATTERN = /[`*_#]/g;
const MATH_DELIMITER_PATTERN = /\$/g;
const BRACKET_PATTERN = /[\[\]\(\)\{\}]/g;

export function extractTypstText(source: string) {
  return source
    .replace(METADATA_BLOCK_PATTERN, " ")
    .replace(COMMENT_PATTERN, " ")
    .replace(BLOCK_COMMAND_PATTERN, " ")
    .replace(INLINE_CALL_WITH_BODY_PATTERN, " $1 ")
    .replace(INLINE_CALL_PATTERN, " ")
    .replace(LABEL_PATTERN, " ")
    .replace(HEADING_PATTERN, "")
    .replace(MATH_DELIMITER_PATTERN, " ")
    .replace(BRACKET_PATTERN, " ")
    .replace(RAW_MARKUP_PATTERN, " ")
    .replace(/https?:\/\/\S+/g, " ")
    .replace(/\b([A-Za-z0-9_-]+):/g, "$1 ")
    .replace(/\s+/g, " ")
    .trim();
}
