const fs = require("fs");
const path = require("path");

const slug = process.argv[2];
const root = process.argv[3] || "src";
const base = `/${slug}/backend`;

function walk(dir) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name);
    if (fs.statSync(p).isDirectory()) walk(p);
    else if (/\.(ts|tsx)$/.test(name)) rewrite(p);
  }
}

function rewrite(file) {
  const before = fs.readFileSync(file, "utf8");
  const after = before
    .split("http://localhost:8000").join(base)
    // "/api/..." '/api/...' `/api/...` の先頭だけ置換
    .replace(/(["'`])\/api\//g, (_, q) => `${q}${base}/api/`);
  if (after !== before) {
    fs.writeFileSync(file, after);
    console.log("rewrote", file);
  }
}

walk(root);