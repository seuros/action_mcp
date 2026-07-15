import { describe, expect, test } from "bun:test";
import { join } from "node:path";
import { scanViews } from "../src/scan.js";

const FIXTURES = join(import.meta.dir, "fixtures", "scan");

describe("scanViews", () => {
  test("finds vanilla modules in flat and directory-index forms only", () => {
    const views = scanViews(join(FIXTURES, "basic"));
    expect(views).toEqual([
      { name: "alpha", file: join(FIXTURES, "basic", "alpha.ts") },
      { name: "beta", file: join(FIXTURES, "basic", "beta.js") },
      { name: "delta", file: join(FIXTURES, "basic", "delta", "index.ts") },
      { name: "epsilon", file: join(FIXTURES, "basic", "epsilon", "index.js") },
      { name: "gamma", file: join(FIXTURES, "basic", "gamma.mjs") },
      { name: "zeta", file: join(FIXTURES, "basic", "zeta", "index.mjs") },
    ]);
  });

  test("rejects duplicate view names (flat file vs directory index)", () => {
    expect(() => scanViews(join(FIXTURES, "duplicate"))).toThrow(
      /duplicate view name/
    );
    expect(() => scanViews(join(FIXTURES, "duplicate"))).toThrow(/foo/);
  });

  test("rejects view files without a default export", () => {
    expect(() => scanViews(join(FIXTURES, "nodefault"))).toThrow(
      /missing a default export/
    );
    expect(() => scanViews(join(FIXTURES, "nodefault"))).toThrow(/bad\.mjs/);
  });

  test("rejects JSX view entries instead of silently dropping them", () => {
    expect(() => scanViews(join(FIXTURES, "unsupported"))).toThrow(
      /unsupported view file extension/
    );
    expect(() => scanViews(join(FIXTURES, "unsupported"))).toThrow(/widget\.tsx/);
    expect(() => scanViews(join(FIXTURES, "unsupported"))).toThrow(/panel\/index\.jsx/);
    expect(() => scanViews(join(FIXTURES, "unsupported"))).toThrow(
      /default-export mount\(root\)/
    );
  });

  test("throws a clear error for a missing views directory", () => {
    expect(() => scanViews(join(FIXTURES, "does-not-exist"))).toThrow(
      /views directory not found/
    );
  });
});
