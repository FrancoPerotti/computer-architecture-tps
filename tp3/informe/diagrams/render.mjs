import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { render } from "pele";

const root = path.dirname(fileURLToPath(import.meta.url));
const sourceDir = path.join(root, "sources");
const svgDir = path.join(root, "svg");
const pdfDir = path.join(root, "pdf");

const diagrams = [
  { name: "sistema-general", fontSize: 20 },
  { name: "pipeline", fontSize: 20 },
  { name: "memorias", fontSize: 20 },
  { name: "flujo-completo", fontSize: 20 },
  { name: "secuencia-load", fontSize: 18 },
  { name: "fsm-carga", fontSize: 20 },
  { name: "fsm-ejecucion", fontSize: 20 },
  { name: "fsm-drenado", fontSize: 20 },
];

const theme = {
  "--_bg": "#ffffff",
  "--_fg": "#1f1f1f",
  "--_m": "#6f6e69",
  "--_l": "#624096",
  "--_s": "#fcfbff",
  "--_a": "#f2f0fa",
  "--_b": "#624096",
  "--_c": "#624096",
  "--_r": "3px",
  "--_fm": "'DejaVu Sans Mono', monospace",
  "--pele-bg": "#ffffff",
  "--pele-fg": "#1f1f1f",
  "--pele-muted": "#6f6e69",
  "--pele-line": "#624096",
  "--pele-surface": "#fcfbff",
  "--pele-surface-alt": "#f2f0fa",
  "--pele-border": "#624096",
  "--pele-accent": "#624096",
  "--pele-radius": "3px",
  "--pele-font": "IBM Plex Sans",
  "--pele-font-mono": "'DejaVu Sans Mono', monospace",
};

function resolveVariables(value) {
  let output = "";
  let index = 0;
  while (index < value.length) {
    const start = value.indexOf("var(", index);
    if (start === -1) {
      output += value.slice(index);
      break;
    }
    output += value.slice(index, start);
    let depth = 1;
    let cursor = start + 4;
    while (cursor < value.length && depth > 0) {
      if (value[cursor] === "(") depth += 1;
      if (value[cursor] === ")") depth -= 1;
      cursor += 1;
    }
    const body = value.slice(start + 4, cursor - 1);
    const comma = body.indexOf(",");
    const name = (comma === -1 ? body : body.slice(0, comma)).trim();
    const fallback = comma === -1 ? null : body.slice(comma + 1).trim();
    if (theme[name] !== undefined) {
      output += theme[name];
    } else if (fallback !== null) {
      output += resolveVariables(fallback);
    } else {
      output += value.slice(start, cursor);
    }
    index = cursor;
  }
  return output;
}

fs.mkdirSync(svgDir, { recursive: true });
fs.mkdirSync(pdfDir, { recursive: true });

for (const diagram of diagrams) {
  const source = fs.readFileSync(
    path.join(sourceDir, `${diagram.name}.mmd`),
    "utf8",
  );
  const result = render(source, {
    fontFamily: "IBM Plex Sans",
    fontFamilyMono: "'DejaVu Sans Mono', monospace",
    fontSize: diagram.fontSize,
    padding: 20,
    responsive: false,
    idPrefix: `tp3-${diagram.name}`,
  });
  const svg = resolveVariables(result.svg);
  const svgPath = path.join(svgDir, `${diagram.name}.svg`);
  const pdfPath = path.join(pdfDir, `${diagram.name}.pdf`);
  fs.writeFileSync(svgPath, svg);
  execFileSync("rsvg-convert", ["-f", "pdf", "-o", pdfPath, svgPath]);
  console.log(
    `${diagram.name}: ${result.width}x${result.height}px -> svg/pdf`,
  );
}
