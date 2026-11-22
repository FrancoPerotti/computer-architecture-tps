const { app, BrowserWindow } = require("electron");
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

const root = __dirname;

// Los SVG de arquitectura usan <foreignObject> para sus etiquetas. Chromium
// los imprime a PDF conservando el texto y el trazado vectorial.
const diagrams = [
  ["fsm-global", "../../docs/diagrams/generated/fsm_global.drawio.svg"],
  ["forwarding", "../../docs/diagrams/generated/forwarding.svg"],
  ["bypass", "../../docs/diagrams/generated/bypass.svg"],
  ["if-normal", "../../docs/diagrams/generated/if_normal.svg"],
  ["id-normal", "../../docs/diagrams/generated/id_normal.svg"],
  ["ex-r", "../../docs/diagrams/generated/ex_r.svg"],
  ["ex-load", "../../docs/diagrams/generated/ex_load.svg"],
  ["ex-branch", "../../docs/diagrams/generated/ex_branch.svg"],
  ["mem-organizacion", "../../docs/diagrams/generated/mem_organizacion.svg"],
  ["mem-load", "../../docs/diagrams/generated/mem_load.svg"],
  ["mem-store", "../../docs/diagrams/generated/mem_store.svg"],
  ["wb-organizacion", "../../docs/diagrams/generated/wb_organizacion.svg"],
  ["fetch-fault", "../../docs/diagrams/generated/fetch_fault.svg"],
];

const only = process.env.DIAGRAM;
const selected = only ? diagrams.filter(([name]) => name === only) : diagrams;

app
  .whenReady()
  .then(async () => {
    for (const [name, relativeSource] of selected) {
      try {
      const svgPath = path.resolve(root, relativeSource);
      const svg = fs.readFileSync(svgPath, "utf8");
      const widthMatch = svg.match(/width="([0-9.]+)"/);
      const heightMatch = svg.match(/height="([0-9.]+)"/);
      const width = widthMatch ? Number(widthMatch[1]) : 1200;
      const height = heightMatch ? Number(heightMatch[1]) : 800;
      const html = `<!doctype html><html><head><meta charset="utf-8"><style>@page { size: ${width}px ${height}px; margin: 0; } html, body { margin: 0; padding: 0; } img { display: block; width: ${width}px; height: ${height}px; }</style></head><body><img src="file://${svgPath}"></body></html>`;
      const htmlPath = path.join(os.tmpdir(), `tp3-${name}.html`);
      fs.writeFileSync(htmlPath, html);
      const win = new BrowserWindow({
        show: false,
        width,
        height,
        webPreferences: { offscreen: true },
      });
      await win.loadFile(htmlPath);
      await new Promise((resolve) => setTimeout(resolve, 1000));
      const pdf = await win.webContents.printToPDF({
        printBackground: true,
        preferCSSPageSize: true,
      });
      fs.writeFileSync(path.join(root, "pdf", `${name}.pdf`), pdf);
      win.destroy();
      fs.unlinkSync(htmlPath);
      console.log(`${name}: SVG existente -> pdf`);
      } catch (error) {
        console.error(`${name}: ${error.message}`);
      }
    }
    app.quit();
  })
  .catch((error) => {
    console.error(error);
    app.quit();
  });
