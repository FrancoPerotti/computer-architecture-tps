const { execFileSync } = require("node:child_process");
const { resolve } = require("node:path");

module.exports = async (context) => {
  if (context.electronPlatformName !== "linux") return;
  const software = resolve(__dirname, "..");
  execFileSync(
    resolve(software, ".venv/bin/python"),
    [resolve(__dirname, "stage_linux.py"), context.appOutDir],
    { stdio: "inherit" },
  );
};
