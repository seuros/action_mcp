/* mcp-ui {
  "csp": { "connectDomains": ["https://api.example.com"] },
  "prefersBorder": true
} */
import "./hello.css";

export default async function mount(root: HTMLElement): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 0));

  root.className = "hello-fixture";

  const message = document.createElement("p");
  message.textContent = "Hello from ActionMCP";

  const button = document.createElement("button");
  button.type = "button";
  let count = 0;
  button.textContent = `clicked ${count}`;
  button.addEventListener("click", () => {
    count += 1;
    button.textContent = `clicked ${count}`;
  });

  root.replaceChildren(message, button);
}
