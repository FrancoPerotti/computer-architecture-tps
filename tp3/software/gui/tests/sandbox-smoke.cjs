const { waitForCore } = require('./ui-commands.cjs')
// Arranque real del paquete: conserva el sandbox nativo de Electron.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const { mkdtempSync, rmSync, existsSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
;(async () => {
  assert.ok(process.env.VIEWRV_PRODUCT, 'Indicar VIEWRV_PRODUCT')
  const root = mkdtempSync(resolve(tmpdir(), 'viewrv-sandbox-'))
  const child = spawn(
    resolve(process.env.VIEWRV_PRODUCT, 'viewrv-gui'),
    [
      '--ozone-platform=x11',
      '--disable-gpu',
      '--remote-debugging-port=0',
      `--user-data-dir=${resolve(root, 'profile')}`,
    ],
    {
      env: {
        ...process.env,
        XDG_RUNTIME_DIR: root,
        XDG_STATE_HOME: resolve(root, 'state'),
        XDG_DATA_HOME: resolve(root, 'data'),
        XDG_CONFIG_HOME: resolve(root, 'config'),
      },
      stdio: ['ignore', 'ignore', 'pipe'],
    },
  )
  let browser
  const exited = new Promise((resolve) => child.once('exit', (code) => resolve(code)))
  try {
    const endpoint = await new Promise((resolve, reject) => {
      let output = ''
      const timer = setTimeout(() => reject(new Error('No se publicó DevTools: ' + output)), 15000)
      child.stderr.on('data', (chunk) => {
        output += chunk.toString()
        const match = output.match(/DevTools listening on (ws:\/\/[^\s]+)/)
        if (match) {
          clearTimeout(timer)
          resolve(match[1])
        }
      })
      child.once('error', (error) => {
        clearTimeout(timer)
        reject(error)
      })
      child.once('exit', () => {
        clearTimeout(timer)
        reject(new Error(output))
      })
    })
    browser = await chromium.connectOverCDP(endpoint)
    const page = browser.contexts()[0].pages()[0]
    await waitForCore(page)
    assert.equal(await page.evaluate(() => typeof window.require), 'undefined')
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    const code = await Promise.race([
      exited,
      new Promise((_, reject) => setTimeout(() => reject(new Error('No terminó la GUI')), 10000)),
    ])
    assert.equal(code, 0)
    const deadline = Date.now() + 5000
    while (existsSync(resolve(root, 'viewrv/core.json')) && Date.now() < deadline)
      await new Promise((r) => setTimeout(r, 50))
    assert.equal(existsSync(resolve(root, 'viewrv/core.json')), false)
    console.log(
      'PC-I01 paquete: GUI iniciada con sandbox nativo, renderer sin Node y cierre correcto.',
    )
  } finally {
    if (browser) await browser.close().catch(() => {})
    if (child.exitCode === null) {
      child.kill('SIGTERM')
      await exited
    }
    rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
