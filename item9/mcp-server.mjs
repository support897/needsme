// Minimal MCP server over stdio (JSON-RPC), standing in for a user's own coding tool
// endpoint (the Claude Code / OpenCode shape from the item 9 design). It offers one
// wake-shaped tool. Used only for the item 9 transport proof: initialize, tools/list,
// tools/call, timed by the client.
import readline from "node:readline";

const rl = readline.createInterface({ input: process.stdin });
function send(obj) { process.stdout.write(JSON.stringify(obj) + "\n"); }

rl.on("line", (line) => {
  let msg;
  try { msg = JSON.parse(line); } catch { return; }
  if (msg.method === "initialize") {
    send({ jsonrpc: "2.0", id: msg.id, result: {
      protocolVersion: "2024-11-05",
      capabilities: { tools: {} },
      serverInfo: { name: "needsme-item9-proof", version: "0.1.0" }
    }});
  } else if (msg.method === "notifications/initialized") {
    // no reply needed
  } else if (msg.method === "tools/list") {
    send({ jsonrpc: "2.0", id: msg.id, result: { tools: [
      { name: "wake_agent", description: "Wake the agent with a task from its owner",
        inputSchema: { type: "object", properties: { task: { type: "string" } }, required: ["task"] } }
    ]}});
  } else if (msg.method === "tools/call") {
    const task = msg.params?.arguments?.task ?? "";
    send({ jsonrpc: "2.0", id: msg.id, result: { content: [
      { type: "text", text: `Agent awake. Started work on: ${task}` }
    ]}});
  } else if (msg.id !== undefined) {
    send({ jsonrpc: "2.0", id: msg.id, error: { code: -32601, message: "method not found" } });
  }
});
