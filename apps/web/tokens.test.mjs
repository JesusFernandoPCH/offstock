// Fails if globals.css drifts from design/tokens.json. Run: node --test
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const tokens = JSON.parse(readFileSync(new URL("../../design/tokens.json", import.meta.url)));
const css = readFileSync(new URL("./src/app/globals.css", import.meta.url), "utf8");
const kebab = (s) => s.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);

for (const theme of ["light", "dark"]) {
  test(`${theme} colors match design/tokens.json`, () => {
    for (const [name, { value }] of Object.entries(tokens.color[theme])) {
      const decl = `--${kebab(name)}: ${value};`;
      assert.ok(css.includes(decl), `missing ${theme} ${decl}`);
    }
  });
}
