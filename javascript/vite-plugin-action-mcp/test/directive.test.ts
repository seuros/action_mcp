import { describe, expect, test } from "bun:test";
import { parseUiDirective } from "../src/directive.js";

describe("parseUiDirective", () => {
  test("parses a valid directive", () => {
    const source = [
      "/* mcp-ui {",
      '  "csp": { "connectDomains": ["https://api.example.com"] },',
      '  "permissions": { "geolocation": {} },',
      '  "prefersBorder": true',
      "} */",
      "export default function mount(root: HTMLElement) { root.textContent = ''; }",
    ].join("\n");

    expect(parseUiDirective(source)).toEqual({
      csp: { connectDomains: ["https://api.example.com"] },
      permissions: { geolocation: {} },
      prefersBorder: true,
    });
  });

  test("parses a single-line directive placed after imports", () => {
    const source = [
      'import "./style.css";',
      '/* mcp-ui { "prefersBorder": false } */',
      "export default function mount(root: HTMLElement) { root.textContent = ''; }",
    ].join("\n");

    expect(parseUiDirective(source)).toEqual({ prefersBorder: false });
  });

  test("uses only the first mcp-ui directive", () => {
    const source = [
      '/* mcp-ui { "prefersBorder": true } */',
      '/* mcp-ui { "prefersBorder": false } */',
      "export default function mount(root: HTMLElement) { root.textContent = ''; }",
    ].join("\n");

    expect(parseUiDirective(source)).toEqual({ prefersBorder: true });
  });

  test("returns null when no directive is present", () => {
    expect(parseUiDirective("export default function mount() {}")).toBeNull();
    // A regular comment must not be mistaken for a directive.
    expect(parseUiDirective("/* just a comment */ export default function mount() {}")).toBeNull();
  });

  test("invalid JSON throws with the view path in the message", () => {
    const source = '/* mcp-ui { "prefersBorder": tru } */\nexport default function mount() {}';
    expect(() => parseUiDirective(source, "app/mcp/views/dashboard.ts")).toThrow(
      /app\/mcp\/views\/dashboard\.ts/
    );
    expect(() => parseUiDirective(source, "app/mcp/views/dashboard.ts")).toThrow(
      /invalid JSON/
    );
  });

  test("directive without a JSON object throws", () => {
    expect(() => parseUiDirective("/* mcp-ui */\nexport default function mount() {}", "v.ts")).toThrow(
      /no JSON object payload/
    );
  });

  test.each([
    ['{ "csp": "https://api.example.com" }', "csp"],
    ['{ "csp": { "connectDomains": "https://api.example.com" } }', "connectDomains"],
    ['{ "domain": 7 }', "domain"],
    ['{ "prefersBorder": "true" }', "prefersBorder"],
  ])("rejects metadata outside the official schema: %s", (payload, field) => {
    const source = `/* mcp-ui ${payload} */\nexport default function mount() {}`;
    expect(() => parseUiDirective(source, "view.ts")).toThrow(/invalid mcp-ui metadata/);
    expect(() => parseUiDirective(source, "view.ts")).toThrow(field);
  });

  test("unterminated directive throws", () => {
    expect(() =>
      parseUiDirective('/* mcp-ui { "a": 1 }\nexport default function mount() {}', "v.ts")
    ).toThrow(/unterminated/);
  });
});
