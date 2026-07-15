/* mcp-ui { "csp": { "connectDomains": ["https://api.example.com"] }, "prefersBorder": true } */
import { App } from "@modelcontextprotocol/ext-apps";

export default async function mount(root: HTMLElement): Promise<void> {
  const button = document.createElement("button");
  const output = document.createElement("pre");
  let count = 0;

  button.textContent = "clicked 0";
  button.disabled = true;
  button.addEventListener("click", () => {
    count += 1;
    button.textContent = `clicked ${count}`;
  });

  output.textContent = "Waiting for tool result...";

  const app = new App(
    { name: "ActionMCP Demo", version: "1.0.0" },
    {},
    { autoResize: true, strict: true },
  );
  app.addEventListener("toolresult", (result) => {
    output.textContent = JSON.stringify(
      result.structuredContent ?? result.content,
      null,
      2,
    );
  });
  app.onerror = (error) => console.error("[action-mcp] app error", error);
  app.onteardown = async () => {
    root.replaceChildren();
    return {};
  };

  root.replaceChildren(button, output);
  await app.connect();
  button.disabled = false;
}
