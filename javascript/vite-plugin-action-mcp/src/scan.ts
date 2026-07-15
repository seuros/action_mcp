import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

/** A view discovered under `app/mcp/views/`. */
export interface ScannedView {
  /** View name, derived from the file (`dashboard.ts`) or directory (`dashboard/index.ts`). */
  name: string;
  /** Absolute path to the view module. */
  file: string;
}

const VIEW_EXTENSIONS = [".ts", ".js", ".mjs"] as const;
const UNSUPPORTED_VIEW_EXTENSIONS = [".tsx", ".jsx"] as const;
const DEFAULT_EXPORT_RE = /export\s+default/;

function stripExtension(fileName: string): string | null {
  for (const ext of VIEW_EXTENSIONS) {
    if (fileName.endsWith(ext)) return fileName.slice(0, -ext.length);
  }
  return null;
}

/**
 * Scans a views directory for vanilla MCP Apps view modules.
 *
 * Conventions:
 * - `<name>.ts` / `<name>.js` / `<name>.mjs` -> view "<name>"
 * - `<name>/index.ts|js|mjs` -> view "<name>"
 *
 * Top-level `index.ts|js|mjs` files are ignored (barrel files, not views).
 *
 * Throws on JSX view entries, duplicate view names, and view files without
 * a default export.
 */
export function scanViews(viewsDir: string): ScannedView[] {
  try {
    if (!statSync(viewsDir).isDirectory()) {
      throw new Error(`[action-mcp] views path is not a directory: ${viewsDir}`);
    }
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error(`[action-mcp] views directory not found: ${viewsDir}`);
    }
    throw err;
  }

  const candidates: ScannedView[] = [];
  const unsupported: string[] = [];

  for (const entry of readdirSync(viewsDir, { withFileTypes: true })) {
    if (entry.isFile()) {
      if (UNSUPPORTED_VIEW_EXTENSIONS.some((ext) => entry.name.endsWith(ext))) {
        unsupported.push(join(viewsDir, entry.name));
        continue;
      }
      const name = stripExtension(entry.name);
      // A top-level index module is a barrel, not a view named "index".
      if (name === null || name === "index") continue;
      candidates.push({ name, file: join(viewsDir, entry.name) });
    } else if (entry.isDirectory()) {
      for (const ext of UNSUPPORTED_VIEW_EXTENSIONS) {
        const indexFile = join(viewsDir, entry.name, `index${ext}`);
        try {
          if (statSync(indexFile).isFile()) unsupported.push(indexFile);
        } catch {
          // index file with this extension does not exist
        }
      }
      for (const ext of VIEW_EXTENSIONS) {
        const indexFile = join(viewsDir, entry.name, `index${ext}`);
        try {
          if (statSync(indexFile).isFile()) {
            candidates.push({ name: entry.name, file: indexFile });
          }
        } catch {
          // index file with this extension does not exist
        }
      }
    }
  }

  assertSupportedExtensions(unsupported);
  assertUniqueNames(candidates);
  assertDefaultExports(candidates);

  return candidates.sort((a, b) => a.name.localeCompare(b.name));
}

function assertSupportedExtensions(files: string[]): void {
  if (files.length === 0) return;

  throw new Error(
    `[action-mcp] unsupported view file extension(s):\n${files
      .sort()
      .map((file) => `  - ${file}`)
      .join("\n")}\nOnly .ts, .js, and .mjs views are supported. Rename each view and default-export mount(root).`
  );
}

function assertUniqueNames(views: ScannedView[]): void {
  const byName = new Map<string, string[]>();
  for (const view of views) {
    const files = byName.get(view.name) ?? [];
    files.push(view.file);
    byName.set(view.name, files);
  }
  const conflicts = [...byName.entries()].filter(([, files]) => files.length > 1);
  if (conflicts.length > 0) {
    const details = conflicts
      .map(([name, files]) => `  "${name}":\n${files.map((f) => `    - ${f}`).join("\n")}`)
      .join("\n");
    throw new Error(
      `[action-mcp] duplicate view name(s) detected:\n${details}\nRename or remove one of the conflicting files.`
    );
  }
}

function assertDefaultExports(views: ScannedView[]): void {
  const missing = views.filter((view) => {
    const source = readFileSync(view.file, "utf8");
    return !DEFAULT_EXPORT_RE.test(source);
  });
  if (missing.length > 0) {
    throw new Error(
      `[action-mcp] view file(s) missing a default export:\n${missing
        .map((v) => `  - ${v.file}`)
        .join("\n")}\nEach view must default-export a mount function.`
    );
  }
}
