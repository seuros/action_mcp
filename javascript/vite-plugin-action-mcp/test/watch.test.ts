import { afterEach, describe, expect, test } from "bun:test";
import { readFileSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { watchViews, type Watcher } from "../src/build.js";

const APP_ROOT = join(import.meta.dir, "fixtures", "app");
const VIEW = join(APP_ROOT, "app", "mcp", "views", "hello.ts");
const OUT_DIR = ".action_mcp/views-watch";
const GENERATED = join(APP_ROOT, OUT_DIR);

const original = readFileSync(VIEW, "utf8");
let watcher: Watcher | undefined;

afterEach(() => {
  watcher?.close();
  watcher = undefined;
  writeFileSync(VIEW, original, "utf8");
  rmSync(GENERATED, { recursive: true, force: true });
});

function waitFor(predicate: () => boolean, timeoutMs = 30_000): Promise<void> {
  return new Promise((resolve, reject) => {
    const started = Date.now();
    const tick = (): void => {
      if (predicate()) return resolve();
      if (Date.now() - started > timeoutMs) return reject(new Error("timed out waiting"));
      setTimeout(tick, 50);
    };
    tick();
  });
}

describe("watchViews", () => {
  test("builds once immediately, then rebuilds on view change", async () => {
    const hashes: string[] = [];
    watcher = await watchViews({
      root: APP_ROOT,
      outDir: OUT_DIR,
      schemaCommand: "node schema.mjs",
      debounceMs: 20,
      onRebuild: (result) => {
        const built = result.views[0];
        if (built) hashes.push(built.hash);
      },
    });

    // Initial build happened before watchViews resolved.
    expect(hashes).toHaveLength(1);

    // Change rendered content so the minified bundle (and its hash) must move.
    writeFileSync(VIEW, original.replace("Hello from ActionMCP", `Changed ${Date.now()}`), "utf8");
    const now = new Date();
    utimesSync(VIEW, now, now);

    await waitFor(() => hashes.length >= 2);
    expect(hashes[1]).not.toBe(hashes[0]);
  }, 120_000);
});
