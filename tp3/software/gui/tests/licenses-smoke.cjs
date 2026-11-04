// Native Help action and the actual offline notice index; no board or browser profile is reused.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { mkdtempSync, readFileSync, existsSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const { pathToFileURL } = require('node:url')
const assert = require('node:assert/strict')
const { menuCommand, waitForCore } = require('./ui-commands.cjs')

const gui = resolve(__dirname, '..'),
  product = process.env.VIEWRV_PRODUCT
if (!product || !existsSync(resolve(product, 'VERIFICATION-ONLY.txt')))
  throw Error('Indicá el producto de verificación que incluye avisos y fuentes.')
const root = mkdtempSync(resolve(tmpdir(), 'viewrv-license-gui-'))
const expected = resolve(product, 'resources/licenses/index.html')
const manifest = JSON.parse(readFileSync(resolve(product, 'resources/licenses/manifest.json')))
const env = {
  ...process.env,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  XDG_DATA_HOME: resolve(root, 'data'),
}
for (const key of ['PYTHONPATH', 'PYTHONHOME', 'LD_PRELOAD', 'LD_LIBRARY_PATH']) delete env[key]

;(async () => {
  const instance = await electron.launch({
    executablePath: resolve(product, 'viewrv-gui'),
    args: ['--disable-gpu', '--ozone-platform=x11', `--user-data-dir=${resolve(root, 'gui')}`],
    env,
  })
  try {
    const page = await instance.firstWindow()
    await waitForCore(page)
    await instance.evaluate(({ shell }) => {
      // Check the requested path without opening the person's external browser.
      shell.openPath = async (path) => {
        globalThis.__licensePath = path
        return ''
      }
    })
    await menuCommand(page, 'Ayuda', 'Avisos y licencias')
    await page.waitForTimeout(100)
    assert.equal(await instance.evaluate(() => globalThis.__licensePath), expected)
    const requests = []
    instance.context().on('request', (request) => {
      if (/^https?:/.test(request.url()) && !/^http:\/\/127\.0\.0\.1:/.test(request.url()))
        requests.push(request.url())
    })
    const opened = instance.waitForEvent('window')
    await instance.evaluate(async ({ BrowserWindow }, path) => {
      const notice = new BrowserWindow({
        width: 1100,
        height: 800,
        show: true,
        webPreferences: { sandbox: true, nodeIntegration: false, contextIsolation: true },
      })
      await notice.loadFile(path)
    }, expected)
    const notices = await opened
    await notices.getByRole('heading', { name: 'Avisos y licencias', exact: true }).waitFor()
    assert.equal(notices.url(), pathToFileURL(expected).href)
    assert.equal(await notices.locator('tbody tr').count(), manifest.components.length)
    assert.match(await notices.locator('body').innerText(), /Franco Perotti y Federico Arnaudo/)
    assert.equal(await notices.evaluate(() => typeof require), 'undefined')
    await notices.screenshot({ path: resolve(gui, '../build/distribution-licenses-index.png') })
    const row = notices.getByRole('row').filter({
      has: notices.getByRole('rowheader', { name: 'monaco-editor', exact: true }),
    })
    await row.getByRole('link', { name: /ThirdPartyNotices/ }).click()
    await notices
      .getByText('THIRD-PARTY SOFTWARE NOTICES AND INFORMATION', { exact: false })
      .waitFor()
    assert.deepEqual(requests, [])
    await notices.close()
    console.log(
      'PASS native Help action, offline index, component count and Monaco supplemental notices',
    )
  } finally {
    await instance.close()
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
