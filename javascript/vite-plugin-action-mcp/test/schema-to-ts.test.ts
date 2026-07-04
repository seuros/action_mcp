import { describe, expect, test } from "bun:test";
import { generateToolTypes, jsonSchemaToTs } from "../src/schema-to-ts.js";

describe("jsonSchemaToTs", () => {
  test("primitives", () => {
    expect(jsonSchemaToTs({ type: "string" })).toBe("string");
    expect(jsonSchemaToTs({ type: "number" })).toBe("number");
    expect(jsonSchemaToTs({ type: "integer" })).toBe("number");
    expect(jsonSchemaToTs({ type: "boolean" })).toBe("boolean");
    expect(jsonSchemaToTs({ type: "null" })).toBe("null");
  });

  test("object with required and optional properties", () => {
    const ts = jsonSchemaToTs({
      type: "object",
      properties: {
        name: { type: "string" },
        age: { type: "integer" },
      },
      required: ["name"],
    });
    expect(ts).toBe('{ "name": string; "age"?: number }');
  });

  test("object without properties falls back to Record", () => {
    expect(jsonSchemaToTs({ type: "object" })).toBe("Record<string, unknown>");
    expect(jsonSchemaToTs({ type: "object", properties: {} })).toBe(
      "Record<string, unknown>"
    );
  });

  test("arrays", () => {
    expect(jsonSchemaToTs({ type: "array", items: { type: "string" } })).toBe(
      "Array<string>"
    );
    expect(jsonSchemaToTs({ type: "array" })).toBe("Array<unknown>");
  });

  test("enum becomes a literal union", () => {
    expect(jsonSchemaToTs({ enum: ["asc", "desc", 3] })).toBe('"asc" | "desc" | 3');
  });

  test("oneOf becomes a union", () => {
    expect(
      jsonSchemaToTs({ oneOf: [{ type: "string" }, { type: "number" }] })
    ).toBe("string | number");
  });

  test("type arrays become a union", () => {
    expect(jsonSchemaToTs({ type: ["string", "null"] })).toBe("string | null");
  });

  test("nested objects", () => {
    const ts = jsonSchemaToTs({
      type: "object",
      properties: {
        filters: {
          type: "object",
          properties: { tags: { type: "array", items: { type: "string" } } },
          required: ["tags"],
        },
      },
      required: ["filters"],
    });
    expect(ts).toBe('{ "filters": { "tags": Array<string> } }');
  });

  test("unknown or missing schema falls back to unknown", () => {
    expect(jsonSchemaToTs(undefined)).toBe("unknown");
    expect(jsonSchemaToTs(null)).toBe("unknown");
    expect(jsonSchemaToTs({})).toBe("unknown");
    expect(jsonSchemaToTs({ type: "wat" })).toBe("unknown");
    expect(jsonSchemaToTs("string")).toBe("unknown");
  });
});

describe("generateToolTypes", () => {
  test("maps tool names to input/output types in ActionMcpTools", () => {
    const dts = generateToolTypes([
      {
        name: "greet",
        inputSchema: {
          type: "object",
          properties: { name: { type: "string" } },
          required: ["name"],
        },
        outputSchema: {
          type: "object",
          properties: { message: { type: "string" } },
        },
      },
      { name: "noop" },
    ]);

    expect(dts).toContain("export interface ActionMcpTools {");
    expect(dts).toContain('"greet": {');
    expect(dts).toContain('    input: { "name": string };');
    expect(dts).toContain('    output: { "message"?: string };');
    expect(dts).toContain('"noop": {');
    expect(dts).toContain("    input: unknown;");
  });
});
