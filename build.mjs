// Build: minify src/main.js + src/styles.css into assets/ and point app/index.html at them.
import { build, transform } from "esbuild";
import { readFileSync, writeFileSync, readdirSync, unlinkSync } from "fs";
import { createHash } from "crypto";
const js = (await transform(readFileSync("src/main.js", "utf8"), { minify: true, format: "esm", target: "es2020" })).code;
const css = (await transform(readFileSync("src/styles.css", "utf8"), { minify: true, loader: "css" })).code;
const us = (await transform(readFileSync("src/user-store.js", "utf8"), { minify: true, format: "esm", target: "es2020" })).code;
const h = (s) => createHash("sha1").update(s).digest("base64url").slice(0, 8);
for (const f of readdirSync("assets")) if (/^main-.*\.(js|css)$/.test(f)) unlinkSync("assets/" + f);
const jn = `main-${h(js)}.js`, cn = `main-${h(css)}.css`;
writeFileSync("assets/" + jn, js); writeFileSync("assets/user-store-BL8C1YaO.js", us); writeFileSync("assets/" + cn, css);
let html = readFileSync("app/index.html", "utf8");
html = html.replace(/main-[\w-]+\.js/, jn).replace(/main-[\w-]+\.css/, cn);
writeFileSync("app/index.html", html);
// Other chunks import the main bundle by filename: repoint them.
for (const f of readdirSync("assets")) {
  if (!f.endsWith(".js") || f === jn) continue;
  const t = readFileSync("assets/" + f, "utf8");
  const u = t.replace(/main-[\w-]+\.js/g, jn).replace(/main-[\w-]+\.css/g, cn);
  if (u !== t) writeFileSync("assets/" + f, u);
}
console.log("built", jn, cn);
