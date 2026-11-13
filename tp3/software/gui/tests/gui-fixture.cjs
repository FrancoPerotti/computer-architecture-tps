// Owns isolated profiles and every process started by a functional GUI test.
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

async function stopCore(core) {
  if (!core.pid || core.exitCode !== null || core.signalCode !== null) return
  const exited = new Promise((resolve) => core.once('exit', resolve))
  core.kill('SIGTERM')
  const force = setTimeout(() => core.kill('SIGKILL'), 5000)
  try {
    await exited
  } finally {
    clearTimeout(force)
  }
}

async function withGuiEnvironment(name, verify, { coreModule = 'session_core', trace } = {}) {
  const root = mkdtempSync(resolve(tmpdir(), `viewrv-${name}-`))
  const tp3 = resolve(gui, '../..')
  const python = resolve(gui, '../.venv/bin/python')
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
  const core = spawn(python, ['-m', `software.tests.viewrv.${coreModule}`], {
    cwd: tp3,
    env,
    stdio: 'ignore',
  })
  let coreFailure, page
  core.once('error', (error) => {
    coreFailure = error
  })
  const instances = []
  async function launch({
    viewport = { width: 1528, height: 771 },
    gpu = false,
    timeout = 30000,
  } = {}) {
    const instance = await electron.launch({
      executablePath: resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        gui,
        ...(gpu ? [] : ['--disable-gpu']),
        '--ozone-platform=x11',
        `--user-data-dir=${resolve(root, 'profile')}`,
      ],
      env,
    })
    instances.push(instance)
    page = await instance.firstWindow()
    page.setDefaultTimeout(timeout)
    await page.setViewportSize(viewport)
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
    await page.getByLabel('viewrv', { exact: true }).waitFor()
    return { page, instance, errors }
  }
  try {
    await until(() => {
      if (coreFailure) throw coreFailure
      return existsSync(resolve(root, 'viewrv/core.json'))
    })
    await verify({ root, gui, tp3, python, env, core, launch })
  } catch (error) {
    if (page && !page.isClosed())
      await page.screenshot({ path: resolve(gui, `../build/${name}-failure.png`) }).catch(() => {})
    throw error
  } finally {
    try {
      for (const instance of instances.reverse()) {
        await instance.evaluate(({ app }) => app.exit()).catch(() => {})
        await instance.close().catch(() => {})
      }
    } finally {
      await stopCore(core)
      rmSync(root, { recursive: true, force: true })
    }
  }
}

async function withGui(name, verify, options) {
  return withGuiEnvironment(
    name,
    async (context) => {
      const window = await context.launch({ timeout: 15000 })
      await verify({ ...context, ...window })
    },
    options,
  )
}
module.exports = { withGui, withGuiEnvironment, until }
