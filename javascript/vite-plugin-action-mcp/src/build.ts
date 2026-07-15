import { execSync } from "node:child_process";
import { mkdirSync, readFileSync, rmSync, statSync, watch, writeFileSync } from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { build, type Plugin, type Rollup } from "vite";
import { parseUiDirective } from "./directive.js";
import { scanViews, type ScannedView } from "./scan.js";
import { generateToolTypes, type ToolSchema } from "./schema-to-ts.js";

export interface BuildViewsOptions {
  /** Project root (the Rails app root). Views/out dirs resolve against it. */
  root: string;
  /** Directory scanned for view modules. Default: `app/mcp/views`. */
  viewsDir?: string;
  /** Bundle + manifest output directory. Default: `.action_mcp/views`. */
  outDir?: string;
  /**
   * Command printing registered tools as JSON
   * (`{"tools":[{"name","inputSchema","outputSchema"}]}`), run with cwd=root.
   * Default: `bin/rails action_mcp:apps:schema`. Failure warns and skips
   * `.action_mcp/types.d.ts` generation; it never fails the build.
   */
  schemaCommand?: string;
}

export interface BuiltView {
  name: string;
  /** Bundle filename relative to the manifest directory. */
  file: string;
  /** Rollup content hash portion of the filename. */
  hash: string;
  /** Literal resource URI, e.g. `ui://views/dashboard.html?v=8f3a91c2`. */
  uri: string;
  /** Stable URI tools declare; resolved to `uri` when tools are listed. */
  logicalUri: string;
  /** Optional `_meta.ui` payload from the view's mcp-ui directive. */
  ui?: Record<string, unknown>;
  /** Bundle size in bytes. */
  bytes: number;
}

export interface BuildViewsResult {
  views: BuiltView[];
  outDir: string;
  manifestPath: string;
}

const VIRTUAL_ENTRY_ID = "virtual:action-mcp-view-entry";
const RESOLVED_ENTRY_ID = `\0${VIRTUAL_ENTRY_ID}`;

/**
 * Compiles every vanilla view module in `viewsDir` into a fully self-contained ES module
 * (one JS file per view; dynamic imports inlined, CSS injected by JS) and
 * writes `manifest.json` (schema v1) plus `.action_mcp/types.d.ts`.
 */
export async function buildViews(options: BuildViewsOptions): Promise<BuildViewsResult> {
  const root = resolve(options.root);
  const viewsDir = resolveFrom(root, options.viewsDir ?? "app/mcp/views");
  const outDir = resolveFrom(root, options.outDir ?? ".action_mcp/views");
  const schemaCommand = options.schemaCommand ?? "bin/rails action_mcp:apps:schema";

  const views = scanViews(viewsDir);

  generateTypes(root, schemaCommand);

  // We manage cleanup ourselves: wipe outDir once before all per-view builds.
  rmSync(outDir, { recursive: true, force: true });
  mkdirSync(outDir, { recursive: true });

  const built: BuiltView[] = [];
  for (const view of views) {
    built.push(await buildView(view, root, outDir));
  }

  const manifestPath = join(outDir, "manifest.json");
  writeFileSync(manifestPath, `${JSON.stringify(buildManifest(built), null, 2)}\n`, "utf8");

  return { views: built, outDir, manifestPath };
}

export interface WatchViewsOptions extends BuildViewsOptions {
  /** Debounce window (ms) coalescing bursts of file events. Default: 150. */
  debounceMs?: number;
  /** Called after each successful rebuild (initial build included). */
  onRebuild?: (result: BuildViewsResult) => void;
  /** Called when a rebuild throws; watching continues. */
  onError?: (error: unknown) => void;
}

export interface Watcher {
  /** Stop watching and release the fs watch handle. */
  close(): void;
}

/**
 * Builds once, then rebuilds every view whenever a file under `viewsDir`
 * changes. Rebuilds are debounced and serialized (a change during a build
 * queues exactly one follow-up). Views are delivered to hosts as inlined
 * resource text, so this is watch-and-rebuild, not websocket HMR: the next
 * tool invocation renders the freshly built bundle.
 */
export async function watchViews(options: WatchViewsOptions): Promise<Watcher> {
  const root = resolve(options.root);
  const viewsDir = resolveFrom(root, options.viewsDir ?? "app/mcp/views");
  const debounceMs = options.debounceMs ?? 150;

  let building = false;
  let pending = false;
  let timer: ReturnType<typeof setTimeout> | undefined;

  const rebuild = async (): Promise<void> => {
    if (building) {
      pending = true;
      return;
    }
    building = true;
    try {
      const result = await buildViews(options);
      options.onRebuild?.(result);
    } catch (error) {
      options.onError?.(error);
    } finally {
      building = false;
      if (pending) {
        pending = false;
        void rebuild();
      }
    }
  };

  await rebuild();

  const watcher = watch(viewsDir, { recursive: true }, () => {
    if (timer !== undefined) clearTimeout(timer);
    timer = setTimeout(() => void rebuild(), debounceMs);
  });

  return {
    close(): void {
      if (timer !== undefined) clearTimeout(timer);
      watcher.close();
    },
  };
}

function resolveFrom(root: string, path: string): string {
  return isAbsolute(path) ? path : resolve(root, path);
}

async function buildView(view: ScannedView, root: string, outDir: string): Promise<BuiltView> {
  const source = readFileSync(view.file, "utf8");
  const ui = parseUiDirective(source, view.file);

  const result = await build({
    root,
    configFile: false,
    envFile: false,
    // Views bundle everything inline; without this vite copies the project's
    // public/ directory (the whole Rails public tree) into outDir.
    publicDir: false,
    logLevel: "warn",
    mode: "production",
    plugins: [virtualEntryPlugin(view), inlineCssPlugin()],
    build: {
      outDir,
      emptyOutDir: false,
      assetsInlineLimit: () => true,
      cssCodeSplit: false,
      sourcemap: false,
      rollupOptions: {
        input: VIRTUAL_ENTRY_ID,
        output: {
          format: "es",
          inlineDynamicImports: true,
          entryFileNames: `${view.name}-[hash].js`,
          assetFileNames: `${view.name}-[hash][extname]`,
        },
      },
    },
  });

  const outputs = Array.isArray(result) ? result : [result];
  const first = outputs[0];
  if (first === undefined || !("output" in first)) {
    throw new Error(`[action-mcp] vite produced no output for view "${view.name}"`);
  }
  const entry = first.output.find(
    (out): out is Rollup.OutputChunk => out.type === "chunk" && out.isEntry
  );
  if (entry === undefined) {
    throw new Error(`[action-mcp] no entry chunk emitted for view "${view.name}"`);
  }

  const fileName = entry.fileName;
  const expectedPrefix = `${view.name}-`;
  if (!fileName.startsWith(expectedPrefix) || !fileName.endsWith(".js")) {
    throw new Error(
      `[action-mcp] unexpected bundle filename "${fileName}" for view "${view.name}"`
    );
  }
  const hash = fileName.slice(expectedPrefix.length, -".js".length);

  const builtView: BuiltView = {
    name: view.name,
    file: fileName,
    hash,
    uri: `ui://views/${view.name}.html?v=${hash}`,
    logicalUri: `ui://views/${view.name}`,
    bytes: statSync(join(outDir, fileName)).size,
  };
  if (ui !== null) builtView.ui = ui;
  return builtView;
}

/** Resolves and loads the virtual bootstrap entry that mounts the view. */
function virtualEntryPlugin(view: ScannedView): Plugin {
  const normalized = view.file.replace(/\\/g, "/");
  const invalidMountMessage = JSON.stringify(
    `[action-mcp] view "${view.name}" must default-export a mount function`
  );
  return {
    name: "action-mcp:virtual-entry",
    resolveId(id) {
      return id === VIRTUAL_ENTRY_ID ? RESOLVED_ENTRY_ID : null;
    },
    load(id) {
      if (id !== RESOLVED_ENTRY_ID) return null;
      return [
        `import mount from ${JSON.stringify(normalized)};`,
        `const root = document.getElementById("root") ?? Object.assign(document.body.appendChild(document.createElement("div")), { id: "root" });`,
        `if (typeof mount !== "function") throw new TypeError(${invalidMountMessage});`,
        `await mount(root);`,
      ].join("\n");
    },
  };
}

/**
 * Two cooperating plugins that make the bundle a single JS file:
 *
 * - a normal-phase plugin records CSS module sources (post vite:css compile)
 *   and feeds them into the entry chunk hash via augmentChunkHash, so a
 *   CSS-only change still busts host-side resource caches;
 * - a post-phase plugin runs after vite:css-post emitted the combined
 *   stylesheet asset, converts it to a JS `<style>` injection prepended to
 *   the entry chunk, and drops the asset.
 */
function inlineCssPlugin(): Plugin[] {
  const cssSources = new Map<string, string>();

  const capture: Plugin = {
    name: "action-mcp:css-hash",
    transform(code, id) {
      if (/\.css(?:\?|$)/.test(id)) cssSources.set(id, code);
      return null;
    },
    augmentChunkHash() {
      if (cssSources.size === 0) return undefined;
      return JSON.stringify([...cssSources.entries()].sort());
    },
  };

  const inline: Plugin = {
    name: "action-mcp:inline-css",
    enforce: "post",
    generateBundle(_options, bundle) {
      let css = "";
      for (const [fileName, output] of Object.entries(bundle)) {
        if (output.type === "asset" && fileName.endsWith(".css")) {
          css +=
            typeof output.source === "string"
              ? output.source
              : new TextDecoder().decode(output.source);
          delete bundle[fileName];
        }
      }
      if (css === "") return;

      const entry = Object.values(bundle).find(
        (out): out is Rollup.OutputChunk => out.type === "chunk" && out.isEntry
      );
      if (entry === undefined) {
        this.error("[action-mcp] CSS emitted but no entry chunk found to inline it into");
      }
      const inject =
        `!function(){try{var d=document,s=d.createElement("style");` +
        `s.textContent=${JSON.stringify(css)};` +
        `(d.head||d.documentElement).appendChild(s)}catch(e){` +
        `console.error("[action-mcp] failed to inject styles",e)}}();\n`;
      entry.code = inject + entry.code;
    },
  };

  return [capture, inline];
}

function buildManifest(views: BuiltView[]): Record<string, unknown> {
  const entries: Record<string, unknown> = {};
  for (const view of views) {
    const entry: Record<string, unknown> = {
      file: view.file,
      hash: view.hash,
      uri: view.uri,
      logicalUri: view.logicalUri,
    };
    if (view.ui !== undefined) entry["ui"] = view.ui;
    entries[view.name] = entry;
  }
  return {
    schemaVersion: 1,
    generator: "@action-mcp/vite-plugin",
    views: entries,
  };
}

/**
 * Runs `schemaCommand` (cwd=root) and writes `.action_mcp/types.d.ts`.
 * Any failure warns and skips — typed tool IO is best-effort.
 */
function generateTypes(root: string, schemaCommand: string): void {
  let stdout: string;
  try {
    stdout = execSync(schemaCommand, {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.warn(
      `[action-mcp] schema command failed (${schemaCommand}): ${message} — skipping types.d.ts`
    );
    return;
  }

  const tools = parseToolSchemas(stdout);
  if (tools === null) {
    console.warn(
      `[action-mcp] schema command (${schemaCommand}) did not print valid {"tools":[...]} JSON — skipping types.d.ts`
    );
    return;
  }

  const typesPath = join(root, ".action_mcp", "types.d.ts");
  mkdirSync(dirname(typesPath), { recursive: true });
  writeFileSync(typesPath, generateToolTypes(tools), "utf8");
}

function parseToolSchemas(stdout: string): ToolSchema[] | null {
  const parsed = tryParseJson(stdout.trim());
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  const tools = (parsed as Record<string, unknown>)["tools"];
  if (!Array.isArray(tools)) return null;
  const valid: ToolSchema[] = [];
  for (const tool of tools) {
    if (
      tool !== null &&
      typeof tool === "object" &&
      typeof (tool as Record<string, unknown>)["name"] === "string"
    ) {
      valid.push(tool as unknown as ToolSchema);
    }
  }
  return valid;
}

/** Rails commands may print boot noise before the JSON; recover the payload. */
function tryParseJson(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    const start = text.indexOf("{");
    const end = text.lastIndexOf("}");
    if (start === -1 || end <= start) return null;
    try {
      return JSON.parse(text.slice(start, end + 1));
    } catch {
      return null;
    }
  }
}
