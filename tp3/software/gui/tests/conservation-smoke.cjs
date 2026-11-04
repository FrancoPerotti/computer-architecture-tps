const { waitForCore } = require('./ui-commands.cjs')
const { menuCommand } = require('./ui-commands.cjs')
// PC-I02: real window closing with a failing recovery adapter and retry/discard choices.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const {
  mkdtempSync,
  existsSync,
  readFileSync,
  writeFileSync,
  unlinkSync,
  rmSync,
} = require('node:fs')
const { resolve } = require('node:path')
const { tmpdir } = require('node:os')
const assert = require('node:assert/strict')
const gui = resolve(__dirname, '..'),
  tp3 = resolve(gui, '../..')
const root = mkdtempSync(resolve(tmpdir(), 'viewrv-pc02-close-'))
const marker = resolve(root, 'recovery.fail')
const env = {
  ...process.env,
  PYTHONPATH: tp3,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_DATA_HOME: resolve(root, 'data'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  VIEWRV_TEST_RECOVERY_FAILURE: marker,
}
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate) {
  const end = Date.now() + 15000
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await sleep(30)
  }
  throw new Error('Condition timed out')
}
;(async () => {
  const child = spawn(
    resolve(gui, '../.venv/bin/python'),
    ['-m', 'software.tests.viewrv.controlled_core'],
    { cwd: tp3, env, stdio: ['ignore', 'ignore', 'pipe'] },
  )
  let instance
  try {
    await until(() => existsSync(resolve(root, 'viewrv/core.json')))
    const connection = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    async function api(route, body, owner) {
      const response = await fetch(connection.base_url + '/api/v1/' + route, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Authorization: 'Bearer ' + connection.access_token,
          'Content-Type': 'application/json',
          ...(owner ? { 'X-Viewrv-Work-Id': owner } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      })
      const result = await response.json()
      if (result.error) throw new Error(JSON.stringify(result.error))
      return result.result
    }
    const cli = (await api('work/register', { client_type: 'cli' })).work_id
    async function launch() {
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
      const page = await instance.firstWindow()
      await page.setViewportSize({ width: 1440, height: 1000 })
      await waitForCore(page)
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      return page
    }
    let page = await launch()
    await menuCommand(page, 'Archivo', 'Crear programa')
    const input = page.locator('.monaco-editor [role="textbox"]').last()
    await input.waitFor({ state: 'attached' })
    await input.focus()
    await page.keyboard.type('kept on retry')
    writeFileSync(marker, 'fail')
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    const dialog = page.getByRole('dialog', { name: 'La aplicación permanece abierta' })
    await dialog.waitFor()
    assert.equal(page.isClosed(), false)
    assert.equal((await api('work/cli/status')).work_id, cli)
    await page.getByRole('button', { name: 'Cancelar', exact: true }).click()
    await input.focus()
    await page.keyboard.press('End')
    await page.keyboard.type(' plus edit')
    unlinkSync(marker)
    const firstClosed = page.waitForEvent('close', { timeout: 15000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await firstClosed
    await instance.close()
    instance = null
    const snapshots = () =>
      require('node:fs')
        .readdirSync(resolve(root, 'data/viewrv/recovery'))
        .map((file) =>
          JSON.parse(readFileSync(resolve(root, 'data/viewrv/recovery', file), 'utf8')),
        )
    assert.ok(snapshots().some((item) => item.text === 'kept on retry plus edit' && item.is_open))
    page = await launch()
    await menuCommand(page, 'Archivo', 'Crear programa')
    await until(async () => (await page.locator('.monaco-editor [role="textbox"]').count()) === 2)
    const other = page.locator('.monaco-editor:visible [role="textbox"]').last()
    await other.waitFor({ state: 'attached' })
    await other.focus()
    await page.keyboard.type('explicitly discarded')
    writeFileSync(marker, 'fail')
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await page.getByRole('dialog', { name: 'La aplicación permanece abierta' }).waitFor()
    const secondClosed = page.waitForEvent('close', { timeout: 15000 })
    await page.getByRole('button', { name: 'Salir sin conservar', exact: true }).click()
    await secondClosed
    await instance.close()
    instance = null
    assert.ok(snapshots().some((item) => item.text === 'kept on retry plus edit'))
    assert.equal(
      snapshots().some((item) => item.text === 'explicitly discarded'),
      false,
    )
    unlinkSync(marker)
    page = await launch()
    await page
      .getByRole('tab', { name: /^Sin título 1(?: ●)?$/, exact: true })
      .first()
      .click()
    await instance.evaluate(({ dialog }, root) => {
      dialog.showSaveDialog = async () => ({ canceled: false, filePath: root + '/moved.s' })
    }, root)
    await menuCommand(page, 'Archivo', 'Guardar como…')
    await until(() => existsSync(resolve(root, 'moved.s')))
    await page
      .getByLabel('Estado del archivo', { exact: true })
      .getByText('moved.s', { exact: true })
      .waitFor()
    await page
      .getByLabel('Estado del archivo', { exact: true })
      .getByRole('img', { name: 'Guardado', exact: true })
      .waitFor()
    unlinkSync(resolve(root, 'moved.s'))
    const restored = page.locator('.monaco-editor:visible [role="textbox"]').first()
    await restored.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.type(' after move')
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await page.getByRole('dialog', { name: 'La aplicación permanece abierta' }).waitFor()
    await instance.evaluate(({ dialog }, root) => {
      dialog.showSaveDialog = async () => ({ canceled: false, filePath: root + '/replacement.s' })
    }, root)
    await page.getByRole('button', { name: 'Guardar en otro destino…', exact: true }).click()
    await until(() => existsSync(resolve(root, 'replacement.s')))
    await until(() => snapshots().some((item) => item.source_path === root + '/replacement.s'))
    assert.equal(
      readFileSync(resolve(root, 'replacement.s'), 'utf8'),
      'kept on retry plus edit after move',
    )
    assert.equal(existsSync(resolve(root, 'moved.s')), false)
    const thirdClosed = page.waitForEvent('close', { timeout: 15000 })
    await page.getByRole('button', { name: 'Reintentar cierre', exact: true }).click()
    await thirdClosed
    await instance.close()
    instance = null
    assert.equal((await api('work/cli/status')).work_id, cli)
    await api('work/finish', {}, cli)
    await until(() => !existsSync(resolve(root, 'viewrv/core.json')))
    console.log(
      'PC-I02 GUI conservation: failed close keeps window, cancel keeps editing, retry preserves code, explicit discard keeps previous recovery; missing source can be saved elsewhere before closing; CLI work survives.',
    )
  } finally {
    if (instance) {
      await instance.evaluate(({ app }) => app.exit()).catch(() => {})
      await instance.close().catch(() => {})
    }
    if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM')
    await new Promise((resolve) => {
      if (child.exitCode !== null || child.signalCode !== null) resolve()
      else child.once('exit', resolve)
    })
    rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
