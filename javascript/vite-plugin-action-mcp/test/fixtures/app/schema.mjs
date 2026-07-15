// Stand-in for `bin/rails action_mcp:apps:schema` in the integration test.
const payload = {
  tools: [
    {
      name: "greet",
      inputSchema: {
        type: "object",
        properties: {
          name: { type: "string" },
          shout: { type: "boolean" },
        },
        required: ["name"],
      },
      outputSchema: {
        type: "object",
        properties: {
          message: { type: "string" },
        },
        required: ["message"],
      },
    },
  ],
};
console.log(JSON.stringify(payload));
