#!/usr/bin/env node
import { relative } from "node:path";
import { buildViews, type BuildViewsOptions, watchViews } from "./build.js";

const USAGE = `Usage: action-mcp-build-views [options]

Compiles vanilla MCP Apps views (app/mcp/views) into self-contained bundles.

Options:
  --root <dir>            Project root (default: cwd)
  --views-dir <dir>       Views directory, relative to root (default: app/mcp/views)
  --out-dir <dir>         Output directory, relative to root (default: .action_mcp/views)
  --schema-command <cmd>  Tool schema command (default: "bin/rails action_mcp:apps:schema")
  --watch                 Rebuild on view changes until interrupted
  -h, --help              Show this help
`;

interface CliFlags {
  root: string;
  viewsDir?: string;
  outDir?: string;
  schemaCommand?: string;
  watch: boolean;
  help: boolean;
}

export function parseArgs(argv: string[]): CliFlags {
  const flags: CliFlags = { root: process.cwd(), watch: false, help: false };
  const mapping: Record<string, "root" | "viewsDir" | "outDir" | "schemaCommand"> = {
    "--root": "root",
    "--views-dir": "viewsDir",
    "--out-dir": "outDir",
    "--schema-command": "schemaCommand",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i] as string;
    if (arg === "-h" || arg === "--help") {
      flags.help = true;
      continue;
    }
    if (arg === "--watch") {
      flags.watch = true;
      continue;
    }
    const eq = arg.indexOf("=");
    const name = eq === -1 ? arg : arg.slice(0, eq);
    const key = mapping[name];
    if (key === undefined) {
      throw new Error(`unknown option: ${arg}\n\n${USAGE}`);
    }
    let value: string | undefined;
    if (eq !== -1) {
      value = arg.slice(eq + 1);
    } else {
      value = argv[i + 1];
      i += 1;
    }
    if (value === undefined || value.startsWith("--")) {
      throw new Error(`missing value for ${name}\n\n${USAGE}`);
    }
    flags[key] = value;
  }

  return flags;
}

async function main(): Promise<void> {
  const flags = parseArgs(process.argv.slice(2));
  if (flags.help) {
    process.stdout.write(USAGE);
    return;
  }

  const options: BuildViewsOptions = { root: flags.root };
  if (flags.viewsDir !== undefined) options.viewsDir = flags.viewsDir;
  if (flags.outDir !== undefined) options.outDir = flags.outDir;
  if (flags.schemaCommand !== undefined) options.schemaCommand = flags.schemaCommand;

  const report = (result: Awaited<ReturnType<typeof buildViews>>): void => {
    if (result.views.length === 0) {
      console.log("[action-mcp] no views found — wrote empty manifest.");
    }
    for (const view of result.views) {
      console.log(`  ${view.name}  ${view.file}  ${view.bytes} bytes`);
    }
    console.log(
      `[action-mcp] built ${result.views.length} view(s) -> ${relative(process.cwd(), result.outDir) || "."}`
    );
  };

  if (flags.watch) {
    const watcher = await watchViews({
      ...options,
      onRebuild: report,
      onError: (error) => console.error(error instanceof Error ? error.message : String(error)),
    });
    console.log("[action-mcp] watching for view changes — press Ctrl+C to stop.");
    const stop = (): void => {
      watcher.close();
      process.exit(0);
    };
    process.on("SIGINT", stop);
    process.on("SIGTERM", stop);
    await new Promise<never>(() => {}); // run until signalled
    return;
  }

  report(await buildViews(options));
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(message);
  process.exit(1);
});
