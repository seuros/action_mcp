import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import {
  cpSync,
  existsSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { buildViews, type BuildViewsResult } from "../src/build.js";

const APP_ROOT = join(import.meta.dir, "fixtures", "app");
const GENERATED = join(APP_ROOT, ".action_mcp");

describe("buildViews (integration)", () => {
  let result: BuildViewsResult;

  beforeAll(async () => {
    rmSync(GENERATED, { recursive: true, force: true });
    result = await buildViews({
      root: APP_ROOT,
      schemaCommand: "node schema.mjs",
    });
  }, 120_000);

  afterAll(() => {
    rmSync(GENERATED, { recursive: true, force: true });
  });

  test("emits exactly one self-contained JS file plus manifest.json", () => {
    const files = readdirSync(result.outDir).sort();
    expect(files).toHaveLength(2);
    expect(files).toContain("manifest.json");
    const jsFiles = files.filter((f) => f.endsWith(".js"));
    expect(jsFiles).toHaveLength(1);
    expect(jsFiles[0]).toMatch(/^hello-[\w-]+\.js$/);
    // No CSS asset — the bundle must be the only artifact.
    expect(files.some((f) => f.endsWith(".css"))).toBe(false);
  });

  test("manifest.json matches schema v1", () => {
    const manifest = JSON.parse(readFileSync(result.manifestPath, "utf8"));
    expect(manifest.schemaVersion).toBe(1);
    expect(manifest.generator).toBe("@action-mcp/vite-plugin");
    expect(Object.keys(manifest.views)).toEqual(["hello"]);

    const hello = manifest.views.hello;
    expect(hello.file).toMatch(/^hello-[\w-]+\.js$/);
    expect(hello.uri).toBe(`ui://views/hello.html?v=${hello.hash}`);
    expect(hello.logicalUri).toBe("ui://views/hello");
    // ui payload from the mcp-ui directive, passed through verbatim.
    expect(hello.ui).toEqual({
      csp: { connectDomains: ["https://api.example.com"] },
      prefersBorder: true,
    });
  });

  test("hash in the emitted filename matches the manifest", () => {
    const manifest = JSON.parse(readFileSync(result.manifestPath, "utf8"));
    const hello = manifest.views.hello;
    expect(hello.file).toBe(`hello-${hello.hash}.js`);
    expect(existsSync(join(result.outDir, hello.file))).toBe(true);

    const [built] = result.views;
    expect(built?.name).toBe("hello");
    expect(built?.file).toBe(hello.file);
    expect(built?.hash).toBe(hello.hash);
    expect(built?.logicalUri).toBe("ui://views/hello");
    expect(built?.bytes).toBeGreaterThan(0);
  });

  test("CSS is injected by JS instead of shipped as an asset", () => {
    const manifest = JSON.parse(readFileSync(result.manifestPath, "utf8"));
    const bundle = readFileSync(join(result.outDir, manifest.views.hello.file), "utf8");
    // The css text from hello.css must live inside the JS bundle...
    expect(bundle).toContain("#bada55");
    expect(bundle).toContain("hello-fixture");
    // ...injected via a <style> element at module load.
    expect(bundle).toContain('createElement("style")');
    // The authored DOM interaction is present without a framework runtime.
    expect(bundle).toContain("addEventListener");
    expect(bundle).not.toMatch(/\breact(?:-dom)?\b/i);
  });

  test("bundles the official stable Apps lifecycle without a framework runtime", async () => {
    const tempRoot = mkdtempSync(join(import.meta.dir, ".mcp-app-lifecycle-"));
    try {
      cpSync(APP_ROOT, tempRoot, { recursive: true });
      const viewPath = join(tempRoot, "app", "mcp", "views", "hello.ts");
      writeFileSync(
        viewPath,
        [
          'import { App } from "@modelcontextprotocol/ext-apps";',
          "export default async function mount(root: HTMLElement): Promise<void> {",
          '  const app = new App({ name: "Lifecycle Test", version: "1.0.0" }, {},',
          "    { autoResize: true, strict: true });",
          '  app.addEventListener("toolresult", () => { root.dataset.result = "received"; });',
          "  app.onteardown = async () => { root.replaceChildren(); return {}; };",
          "  await app.connect();",
          "}",
        ].join("\n"),
        "utf8"
      );

      const lifecycleResult = await buildViews({
        root: tempRoot,
        schemaCommand: "node schema.mjs",
      });
      const manifest = JSON.parse(readFileSync(lifecycleResult.manifestPath, "utf8"));
      const bundle = readFileSync(
        join(lifecycleResult.outDir, manifest.views.hello.file),
        "utf8"
      );

      expect(bundle).toContain("2026-01-26");
      expect(bundle).toContain("ui/initialize");
      expect(bundle).toContain("ui/notifications/initialized");
      expect(bundle).toContain("toolresult");
      expect(bundle).not.toMatch(/\breact(?:-dom)?\b/i);
    } finally {
      rmSync(tempRoot, { recursive: true, force: true });
    }
  }, 120_000);

  test("invokes and awaits the default mount function with #root", async () => {
    const manifest = JSON.parse(readFileSync(result.manifestPath, "utf8"));
    const bundlePath = join(result.outDir, manifest.views.hello.file);
    const root = new FakeElement("div");
    root.id = "root";
    const head = new FakeElement("head");
    const body = new FakeElement("body");
    const documentElement = new FakeElement("html");
    const previousDocument = Reflect.get(globalThis, "document");

    Reflect.set(globalThis, "document", {
      body,
      head,
      documentElement,
      createElement: (tagName: string) => new FakeElement(tagName),
      getElementById: (id: string) => (id === "root" ? root : null),
    });

    try {
      await import(`${pathToFileURL(bundlePath).href}?test=${Date.now()}`);
      expect(root.className).toBe("hello-fixture");
      expect(root.children.map((child) => child.textContent)).toEqual([
        "Hello from ActionMCP",
        "clicked 0",
      ]);
      expect(head.children).toHaveLength(1);
      expect(head.children[0]?.tagName).toBe("style");
    } finally {
      if (previousDocument === undefined) {
        Reflect.deleteProperty(globalThis, "document");
      } else {
        Reflect.set(globalThis, "document", previousDocument);
      }
    }
  });

  test("generates .action_mcp/types.d.ts from the schema command", () => {
    const dts = readFileSync(join(GENERATED, "types.d.ts"), "utf8");
    expect(dts).toContain("export interface ActionMcpTools {");
    expect(dts).toContain('"greet": {');
    expect(dts).toContain('input: { "name": string; "shout"?: boolean };');
    expect(dts).toContain('output: { "message": string };');
  });

  test("a failing schema command warns but does not fail the build", async () => {
    const outDir = ".action_mcp/views-nofail";
    const second = await buildViews({
      root: APP_ROOT,
      outDir,
      schemaCommand: "node -e \"process.exit(3)\"",
    });
    expect(second.views).toHaveLength(1);
    expect(existsSync(second.manifestPath)).toBe(true);
    rmSync(join(APP_ROOT, outDir), { recursive: true, force: true });
  }, 120_000);

  test("rejects a non-function default export after creating #root", async () => {
    const tempRoot = mkdtempSync(join(import.meta.dir, ".invalid-mount-app-"));
    const previousDocument = Reflect.get(globalThis, "document");
    try {
      cpSync(APP_ROOT, tempRoot, { recursive: true });
      const viewPath = join(tempRoot, "app", "mcp", "views", "hello.ts");
      writeFileSync(viewPath, "export default 42;\n", "utf8");

      const invalidResult = await buildViews({
        root: tempRoot,
        schemaCommand: "node schema.mjs",
      });
      const manifest = JSON.parse(readFileSync(invalidResult.manifestPath, "utf8"));
      const bundlePath = join(invalidResult.outDir, manifest.views.hello.file);
      const body = new FakeElement("body");

      Reflect.set(globalThis, "document", {
        body,
        head: new FakeElement("head"),
        documentElement: new FakeElement("html"),
        createElement: (tagName: string) => new FakeElement(tagName),
        getElementById: () => null,
      });

      await expect(
        import(`${pathToFileURL(bundlePath).href}?test=${Date.now()}`)
      ).rejects.toThrow('view "hello" must default-export a mount function');
      expect(body.children).toHaveLength(1);
      expect(body.children[0]?.id).toBe("root");
    } finally {
      if (previousDocument === undefined) {
        Reflect.deleteProperty(globalThis, "document");
      } else {
        Reflect.set(globalThis, "document", previousDocument);
      }
      rmSync(tempRoot, { recursive: true, force: true });
    }
  }, 120_000);

  test("large imported assets are inlined into the self-contained bundle", async () => {
    const tempRoot = mkdtempSync(join(import.meta.dir, ".asset-app-"));
    try {
      cpSync(APP_ROOT, tempRoot, { recursive: true });
      const viewPath = join(tempRoot, "app", "mcp", "views", "hello.ts");
      const source = readFileSync(viewPath, "utf8")
        .replace(
          'import "./hello.css";',
          'import "./hello.css";\nimport largeAssetUrl from "./large.png";'
        )
        .replace(
          'root.className = "hello-fixture";',
          'root.className = "hello-fixture";\n  root.dataset.asset = largeAssetUrl;'
        );
      writeFileSync(viewPath, source, "utf8");
      writeFileSync(join(tempRoot, "app", "mcp", "views", "large.png"), Buffer.alloc(10_000, 1));

      const assetResult = await buildViews({
        root: tempRoot,
        schemaCommand: "node schema.mjs",
      });
      const files = readdirSync(assetResult.outDir);
      const manifest = JSON.parse(readFileSync(assetResult.manifestPath, "utf8"));
      const bundle = readFileSync(join(assetResult.outDir, manifest.views.hello.file), "utf8");

      expect(files).toHaveLength(2);
      expect(files.some((file) => file.endsWith(".png"))).toBe(false);
      expect(bundle).toContain("data:image/png;base64,");
    } finally {
      rmSync(tempRoot, { recursive: true, force: true });
    }
  }, 120_000);
});

class FakeElement {
  readonly children: FakeElement[] = [];
  readonly dataset: Record<string, string> = {};
  className = "";
  id = "";
  textContent = "";

  constructor(readonly tagName: string) {}

  appendChild(child: FakeElement): FakeElement {
    this.children.push(child);
    return child;
  }

  addEventListener(): void {}

  replaceChildren(...children: FakeElement[]): void {
    this.children.splice(0, this.children.length, ...children);
  }
}
