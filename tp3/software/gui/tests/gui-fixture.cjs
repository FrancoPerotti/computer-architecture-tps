const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const { mkdtempSync, existsSync, rmSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const gui = resolve(__dirname, '..')

async function until(predicate, timeout = 15000) {
  const end = Date.now() + timeout
  let cause
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch (error) {
      cause = error
    }
    await new Promise((resolve) => setTimeout(resolve, 30))
  }
  throw new Error('GUI condition timed out', { cause })
}

async function withGui(name, verify, { coreModule = 'session_core', trace } = {}) {
  const root = mkdtempSync(resolve(tmpdir(), `viewrv-${name}-`))
  const tp3 = resolve(gui, '../..')
  const env = {
    ...process.env,
    PYTHONPATH: tp3,
    XDG_RUNTIME_DIR: root,
    XDG_STATE_HOME: resolve(root, 'state'),
    XDG_CONFIG_HOME: resolve(root, 'config'),
    XDG_DATA_HOME: resolve(root, 'data'),
    VIEWRV_TEST_CONTROL: root,
    ...(trace ? { VIEWRV_EDUCATIONAL_TRACE: trace } : {}),
  }
  const core = spawn(
    resolve(gui, '../.venv/bin/python'),
    ['-m', `software.tests.viewrv.${coreModule}`],
    { cwd: tp3, env, stdio: 'ignore' },
  )
  let instance, page
  try {
    await until(() => existsSync(resolve(root, 'viewrv/core.json')))
    instance = await electron.launch({
      executablePath: resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        gui,
        '--disable-gpu',
        '--ozone-platform=x11',
        `--user-data-dir=${resolve(root, 'profile')}`,
      ],
      env,
    })
    page = await instance.firstWindow()
    page.setDefaultTimeout(15000)
    await page.setViewportSize({ width: 1528, height: 771 })
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
    await page.getByLabel('viewrv', { exact: true }).waitFor()
    await verify({ page, instance, root, errors, gui })
  } catch (error) {
    if (page && !page.isClosed())
      await page.screenshot({ path: resolve(gui, `../build/${name}-failure.png`) }).catch(() => {})
    throw error
  } finally {
    if (instance) {
      await instance.evaluate(({ app }) => app.exit()).catch(() => {})
      await instance.close().catch(() => {})
    }
    if (core.exitCode === null && core.signalCode === null) core.kill('SIGTERM')
    await new Promise((resolve) =>
      core.exitCode !== null || core.signalCode !== null ? resolve() : core.once('exit', resolve),
    )
    rmSync(root, { recursive: true, force: true })
  }
}
module.exports = { withGui, until }
