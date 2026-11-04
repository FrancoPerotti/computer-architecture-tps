// Breakpoints persist by source version, but are visible only while debug is open.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const { mkdtempSync, existsSync, rmSync, readFileSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const gui = resolve(__dirname, '..'),
  tp3 = resolve(gui, '../..'),
  root = mkdtempSync(resolve(tmpdir(), 'viewrv-breakpoint-visibility-'))
const env = {
  ...process.env,
  PYTHONPATH: tp3,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  XDG_DATA_HOME: resolve(root, 'data'),
  VIEWRV_TEST_CONTROL: root,
  VIEWRV_EDUCATIONAL_TRACE: 'addition',
}
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate, timeout = 10000) {
  const end = Date.now() + timeout
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await delay(30)
  }
  throw Error('Visual condition timed out')
}
;(async () => {
  const core = spawn(
    resolve(gui, '../.venv/bin/python'),
    ['-m', 'software.tests.viewrv.educational_core'],
    { cwd: tp3, env, stdio: ['ignore', 'ignore', 'pipe'] },
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
    await page.setViewportSize({ width: 1528, height: 771 })
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
    await page.getByLabel('viewrv', { exact: true }).waitFor()
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    await page
      .getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
      .getByRole('button', { name: 'Sumar dos números', exact: true })
      .click()
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    async function loadDebug() {
      await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
      await page.getByRole('button', { name: 'Cargar', exact: true }).click()
      await until(() =>
        page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).waitFor()
    }
    const steps = () =>
      readFileSync(resolve(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    const editor = page.locator('.monaco-editor:visible').first()
    const marginWidth = () =>
      editor
        .locator('.margin')
        .first()
        .evaluate((node) => node.getBoundingClientRect().width)
    const breakpointMarks = () =>
      editor.locator(
        '.viewrv-breakpoint, .viewrv-breakpoint-slot, [class*=viewrv-breakpoint-targets-]',
      )
    const editWidth = await marginWidth()
    await loadDebug()
    assert.equal(steps(), 0)
    await editor.locator('.viewrv-breakpoint-slot').first().click()
    await page
      .getByRole('dialog', { name: 'Breakpoint de la línea 2', exact: true })
      .getByRole('button', { name: 'EX/MEM · entrada a MEM', exact: true })
      .click()
    await editor.locator('.viewrv-breakpoint-targets-4').waitFor()
    assert.ok((await marginWidth()) > editWidth)
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await editor.locator('.viewrv-stage-badge').waitFor()
    assert.equal(steps(), 1)
    // Pausing/completion keeps debug open. Explicit Stop returns to editing and hides its source annotations.
    await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).waitFor()
    await until(async () => (await breakpointMarks().count()) === 0)
    assert.equal(await editor.locator('.viewrv-stage-badge').count(), 0)
    assert.equal(await page.getByRole('button', { name: /instrucción de la línea/ }).count(), 0)
    assert.equal(
      await page.getByRole('button', { name: /^Elegir registro del breakpoint/ }).count(),
      0,
    )
    assert.equal(await marginWidth(), editWidth)
    assert.equal(steps(), 1, 'Stop emitted STEP')
    await page.screenshot({ path: resolve(gui, '../build/breakpoint-visibility-edit.png') })
    await loadDebug()
    await editor.locator('.viewrv-breakpoint-targets-4').waitFor()
    assert.equal(
      await editor.locator('.viewrv-breakpoint').count(),
      1,
      'Same-version breakpoint lost',
    )
    assert.equal(await editor.locator('.viewrv-stage-badge').count(), 0)
    assert.equal(steps(), 1, 'Reopening emitted STEP')
    await page.screenshot({ path: resolve(gui, '../build/breakpoint-visibility-reopened.png') })
    await page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).click()
    await editor.locator('.viewrv-breakpoint-targets-4').waitFor()
    assert.equal(steps(), 1, 'Restart emitted STEP')
    await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).waitFor()
    await until(async () => (await breakpointMarks().count()) === 0)
    const input = editor.locator('[role="textbox"]').first()
    await input.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.type('\n# nueva revisión')
    await until(() => page.getByRole('tab', { name: 'addition.s ●', exact: true }).isVisible())
    assert.equal(await breakpointMarks().count(), 0)
    assert.equal(await marginWidth(), editWidth)
    assert.deepEqual(errors, [])
    console.log(
      'Breakpoint visibility: explicit Stop removes dots, targets, empty slots, stage annotations and follow controls; gutter returns to editing width; same-version LOAD/debug and Restart preserve the breakpoint without extra STEP; editing after Stop stays clear. Isolated core, one literal UART capture.',
    )
  } catch (e) {
    if (page && !page.isClosed())
      await page
        .screenshot({ path: resolve(gui, '../build/breakpoint-visibility-failure.png') })
        .catch(() => {})
    throw e
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
})().catch((e) => {
  console.error(e)
  process.exitCode = 1
})
