// Item 9 proof client: spawns the MCP server, runs initialize, tools/list and a
// wake_agent call, and prints the elapsed time for the whole connect + wake.
import { spawn } from "node:child_process";
import readline from "node:readline";

const t0 = Date.now();
const child = spawn("node", ["mcp-server.mjs"], { stdio: ["pipe", "pipe", "inherit"] });
const rl = readline.createInterface({ input: child.stdout });
const pending = new Map();
let nextId = 1;
rl.on("line", (line) => {
  let msg; try { msg = JSON.parse(line); } catch { return; }
  if (msg.id !== undefined && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
});
function call(method, params) {
  const id = nextId++;
  return new Promise((resolve) => {
    pending.set(id, resolve);
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
  });
}

const init = await call("initialize", { protocolVersion: "2024-11-05", capabilities: {}, clientInfo: { name: "needsme-app-design", version: "0.1.0" } });
console.log("initialize:", init.result?.serverInfo?.name, "protocol", init.result?.protocolVersion);
child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }) + "\n");
const tools = await call("tools/list", {});
console.log("tools:", tools.result.tools.map((t) => t.name).join(", "));
const tWake = Date.now();
const woke = await call("tools/call", { name: "wake_agent", arguments: { task: "Read the room and file the to-dos" } });
console.log("wake reply:", woke.result.content[0].text);
console.log(`connect+list: ${tWake - t0} ms · wake call: ${Date.now() - tWake} ms · total: ${Date.now() - t0} ms`);
child.kill();
