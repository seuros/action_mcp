import * as ExtApps from "@modelcontextprotocol/ext-apps";
import type { ZodType } from "zod";

// ext-apps 1.7.4 exports this schema at runtime, but its root NodeNext
// declaration does not surface generated schema re-exports.
const McpUiResourceMetaSchema = (
  ExtApps as unknown as {
    McpUiResourceMetaSchema: ZodType<Record<string, unknown>>;
  }
).McpUiResourceMetaSchema;

/**
 * Parses the per-view UI metadata directive:
 *
 * ```ts
 * /* mcp-ui {
 *   "csp": { "connectDomains": ["https://api.example.com"] },
 *   "prefersBorder": true
 * } *\/
 * ```
 *
 * Extracts the first `/* mcp-ui { ...json... } *\/` block comment from
 * `source`. The JSON payload starts at the first `{` after "mcp-ui" and ends
 * at the comment close. Returns the parsed object, or `null` when no
 * directive is present. Invalid JSON throws, with `viewPath` in the message.
 */
export function parseUiDirective(
  source: string,
  viewPath = "<source>"
): Record<string, unknown> | null {
  const open = source.match(/\/\*\s*mcp-ui\b/);
  if (open === null || open.index === undefined) return null;

  const afterMarker = open.index + open[0].length;
  const close = source.indexOf("*/", afterMarker);
  if (close === -1) {
    throw new Error(`[action-mcp] unterminated mcp-ui directive in ${viewPath}`);
  }

  const braceStart = source.indexOf("{", afterMarker);
  if (braceStart === -1 || braceStart > close) {
    throw new Error(
      `[action-mcp] mcp-ui directive in ${viewPath} has no JSON object payload`
    );
  }

  const payload = source.slice(braceStart, close).trim();
  let parsed: unknown;
  try {
    parsed = JSON.parse(payload);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    throw new Error(
      `[action-mcp] invalid JSON in mcp-ui directive of ${viewPath}: ${message}`
    );
  }

  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(
      `[action-mcp] mcp-ui directive in ${viewPath} must be a JSON object`
    );
  }

  const validation = McpUiResourceMetaSchema.safeParse(parsed);
  if (!validation.success) {
    const issues = validation.error.issues
      .map((issue) => {
        const path = issue.path.length > 0 ? `${issue.path.join(".")}: ` : "";
        return `${path}${issue.message}`;
      })
      .join("; ");
    throw new Error(`[action-mcp] invalid mcp-ui metadata in ${viewPath}: ${issues}`);
  }

  return parsed as Record<string, unknown>;
}
