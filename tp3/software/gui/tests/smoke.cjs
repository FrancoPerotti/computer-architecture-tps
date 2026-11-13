const { waitForCore } = require('./ui-commands.cjs')
const { menuCommand } = require('./ui-commands.cjs')
// Ejecutar con PLAYWRIGHT_MODULE apuntando a Playwright si no está instalado localmente.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { mkdtempSync, mkdirSync, existsSync, rmSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { execFileSync } = require('node:child_process')
const gui = resolve(__dirname, '..')
const root = mkdtempSync(resolve(tmpdir(), 'viewrv-gui-'))
mkdirSync(resolve(root, 'state'))
;(async () => {
  const product = process.env.VIEWRV_PRODUCT
  const environment = {
    ...process.env,
    XDG_RUNTIME_DIR: root,
    XDG_STATE_HOME: resolve(root, 'state'),
    XDG_DATA_HOME: resolve(root, 'data'),
    XDG_CONFIG_HOME: resolve(root, 'config'),
    PYTHONPATH: resolve(gui, '../..'),
  }
  const executablePath = product
    ? resolve(product, 'viewrv-gui')
    : resolve(gui, 'node_modules/electron/dist/electron')
  const args = [
    ...(product ? [] : [gui]),
    '--disable-gpu',
    '--ozone-platform=x11',
    `--user-data-dir=${resolve(root, 'gui-profile')}`,
  ]
  const instance = await electron.launch({ executablePath, args, env: environment })
  try {
    const page = await instance.firstWindow()
    await page.setViewportSize({ width: 1440, height: 960 })
    const errors = []
    const externalRequests = []
    page.on('request', (request) => {
      if (/^https?:/.test(request.url()) && !/^http:\/\/127\.0\.0\.1:/.test(request.url()))
        externalRequests.push(request.url())
    })
    page.on('pageerror', (error) => errors.push(String(error)))
    page.on('console', (message) => {
      if (message.type() === 'error') console.error(message.text())
    })
    await waitForCore(page)
    await page.waitForFunction(() => document.querySelector('iframe') !== null)
    const frame = page.frameLocator('iframe')
    await frame.locator('#instruction-select:not([disabled])').waitFor({ timeout: 20000 })
    await frame.locator('#instruction-select').selectOption({ index: 1 })
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Crear programa')
    await page.locator('.monaco-editor:not(.viewrv-editor-overlays)').waitFor({ timeout: 10000 })
    await page.getByRole('button', { name: 'Visor interactivo', exact: true }).click()
    await waitForCore(page)
    await frame.locator('#instruction-select:not([disabled])').waitFor({ timeout: 20000 })
    await frame.locator('#diagram svg').first().waitFor({ timeout: 10000 })
    assert.deepEqual(errors, [])
    assert.deepEqual(externalRequests, [])
    await page.screenshot({
      path: resolve(gui, `../build/${process.env.VIEWRV_EVIDENCE_PREFIX || 'gui-pc-i02'}-base.png`),
    })
    await page.evaluate(async () => {
      const connection = await window.viewrvDesktop.getCoreConnection()
      const response = await fetch(connection.base_url + '/api/v1/work/register', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${connection.access_token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ client_type: 'cli' }),
      })
      if (!response.ok) throw new Error('CLI work registration failed')
    })
    const closed = page.waitForEvent('close', { timeout: 10000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    assert.equal(existsSync(resolve(root, 'viewrv/core.json')), true, 'GUI closed the CLI core')
    const cli = product ? resolve(product, 'viewrv') : resolve(gui, '../.venv/bin/python')
    const prefix = product ? [] : ['-m', 'software.viewrv.cli']
    const status = JSON.parse(
      execFileSync(cli, [...prefix, '--output', 'json', 'work', 'status'], {
        env: environment,
        cwd: root,
        encoding: 'utf8',
        timeout: 20000,
      }),
    )
    assert.ok(status.result.work_id)
    const finished = JSON.parse(
      execFileSync(cli, [...prefix, '--output', 'json', 'work', 'finish'], {
        env: environment,
        cwd: root,
        encoding: 'utf8',
        timeout: 20000,
      }),
    )
    assert.equal(finished.result.finished, true)
    const deadline = Date.now() + 5000
    while (existsSync(resolve(root, 'viewrv/core.json')) && Date.now() < deadline)
      await new Promise((r) => setTimeout(r, 50))
    assert.equal(existsSync(resolve(root, 'viewrv/core.json')), false)
    console.log('PC-I01 GUI: core, SSE, visor offline, Monaco, navegación y cierre correctos.')
  } finally {
    const windows = instance.windows()
    if (windows[0] && !windows[0].isClosed()) {
      await windows[0].evaluate(() => window.viewrvDesktop.requestWindowClose()).catch(() => {})
    }
    await instance.evaluate(({ app }) => app.exit()).catch(() => {})
    await instance.close()
    rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
