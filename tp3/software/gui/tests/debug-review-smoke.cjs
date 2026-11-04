// Debug visual review, comments 1–4: actual renderer and isolated core; no hardware acceptance.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const { mkdtempSync, existsSync, rmSync, readFileSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const gui = resolve(__dirname, '..'),
  tp3 = resolve(gui, '../..'),
  root = mkdtempSync(resolve(tmpdir(), 'viewrv-debug-review-'))
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
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await page.getByRole('heading', { name: 'Listo para el primer ciclo', exact: true }).waitFor()
    const region = page.getByRole('region', { name: 'Estado del procesador', exact: true })
    assert.equal(
      await region.getByText('Estado global recibido', { exact: true }).count(),
      0,
      'Global state fabricated before capture',
    )
    for (let cycle = 1; cycle <= 4; cycle++) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await region.getByText(String(cycle), { exact: true }).first().waitFor()
    }
    const bank = region.getByText('Banco de registros arquitectónicos · x0–x31', { exact: true })
    assert.equal(
      await bank.evaluate((n) => n.closest('details').open),
      false,
      'Register bank defaults to expanded',
    )
    const globalState = region.getByRole('region', { name: 'Estado global recibido', exact: true })
    await globalState
      .getByRole('heading', { name: 'Estado global recibido', exact: true })
      .waitFor()
    assert.equal(await globalState.locator('summary, details').count(), 0)
    assert.equal(await region.getByText(/fault_cause y fault_pc solo son vigentes/).count(), 0)
    for (const latch of ['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB']) {
      const card = region.getByRole('region', { name: `Registro ${latch}`, exact: true })
      assert.equal(
        await card.locator('summary, details').count(),
        0,
        'Interstage registers must always be visible',
      )
      assert.ok((await card.locator('code').count()) > 0)
    }
    const ifid = region.getByRole('region', { name: 'Registro IF/ID', exact: true })
    assert.equal(
      await ifid
        .locator('div')
        .filter({ has: page.getByLabel('Línea 5', { exact: true }) })
        .last()
        .innerText(),
      'halt\n#5',
    )
    const disclosure = globalState.getByRole('heading', {
      name: 'Estado global recibido',
      exact: true,
    })
    await disclosure.click()
    assert.equal(await globalState.getByLabel('Formato de pc', { exact: true }).isVisible(), true)
    const format = region.getByLabel('Formato de global_state', { exact: true })
    assert.equal(await format.evaluate((n) => getComputedStyle(n).appearance), 'none')
    const lastArrow = page.getByRole('button', {
      name: 'Elegir registro del breakpoint de la línea 5',
      exact: true,
    })
    await lastArrow.click()
    const lastPicker = page.getByRole('dialog', { name: 'Breakpoint de la línea 5', exact: true })
    const beforeScroll = await lastArrow.boundingBox()
    const sourceBox = await page.locator('.monaco-editor:visible').first().boundingBox()
    await page.mouse.move(sourceBox.x + sourceBox.width - 30, sourceBox.y + 90)
    await page.mouse.wheel(0, 20)
    await until(async () => (await lastArrow.boundingBox()).y < beforeScroll.y - 1)
    await until(async () => {
      const a = await lastArrow.boundingBox(),
        p = await lastPicker.boundingBox()
      return a && p && Math.abs(p.x - a.x) < 2 && Math.abs(p.y - a.y - a.height - 4) < 2
    })
    await page.mouse.wheel(0, -20)
    await until(async () => Math.abs((await lastArrow.boundingBox()).y - beforeScroll.y) < 1)
    await lastPicker.getByRole('button').first().press('Escape')
    await page.locator('.viewrv-breakpoint-slot').first().click()
    const popup = page.getByRole('dialog', { name: /Breakpoint de la línea/ })
    await popup.waitFor()
    assert.equal(await popup.getByRole('button').count(), 4)
    assert.equal(await popup.getByText('Cerrar selector', { exact: true }).count(), 0)
    assert.equal(await popup.locator('strong').filter({ hasText: 'detener en' }).count(), 0)
    await popup
      .getByRole('button', { name: 'IF/ID · entrada a ID', exact: true })
      .press('ArrowDown')
    assert.equal(
      await page.evaluate(() => document.activeElement.getAttribute('aria-label')),
      'ID/EX · entrada a EX',
    )
    await popup.getByRole('button', { name: 'ID/EX · entrada a EX', exact: true }).press('Escape')
    await popup.waitFor({ state: 'hidden' })
    await page.locator('.viewrv-breakpoint-slot').first().click()
    await popup.waitFor()
    await disclosure.click()
    await popup.waitFor({ state: 'hidden' })
    await disclosure.click()
    await page.locator('.viewrv-breakpoint-slot').first().click()
    await popup.waitFor()
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r2-breakpoints.png') })
    await popup.getByRole('button', { name: 'IF/ID · entrada a ID', exact: true }).click()
    await popup.waitFor({ state: 'hidden' })
    await until(async () => (await page.locator('.viewrv-breakpoint').count()) > 0)
    await page.locator('.viewrv-breakpoint').first().click()
    await popup.waitFor()
    assert.equal(
      await popup
        .getByRole('button', { name: 'IF/ID · entrada a ID', exact: true })
        .getAttribute('aria-pressed'),
      'true',
    )
    await popup.getByRole('button', { name: 'IF/ID · entrada a ID', exact: true }).click()
    await popup.waitFor({ state: 'hidden' })
    await page.screenshot({ path: resolve(gui, '../build/debug-review-global.png') })
    await region.getByText('Guía educativa del ejemplo', { exact: true }).click()
    const guide = region.getByLabel('Referencia educativa del ejemplo', { exact: true })
    await guide.getByRole('heading', { name: 'Sumar dos números', level: 3, exact: true }).waitFor()
    await guide.getByRole('heading', { name: 'Esperado · diseño', level: 4, exact: true }).waitFor()
    const expected = guide.getByRole('region', { name: 'Guía del ciclo observado', exact: true }),
      received = guide.getByRole('region', { name: 'Captura recibida del ejemplo', exact: true })
    assert.deepEqual(
      await expected.locator('tbody tr').first().getByRole('cell').allTextContents(),
      ['0x0000000c', 'aparición 4'],
    )
    assert.deepEqual(
      await received.locator('tbody tr').first().getByRole('cell').allTextContents(),
      ['Válido', '0x0000000c'],
    )
    assert.equal(await expected.locator('tbody tr').count(), 4)
    assert.equal(await received.locator('tbody tr').count(), 4)
    await guide.scrollIntoViewIfNeeded()
    await page.screenshot({ path: resolve(gui, '../build/debug-review-guide.png') })
    await region.getByText('Actividad inferida del ciclo', { exact: true }).click()
    for (const stage of ['IF', 'ID', 'EX', 'MEM', 'WB'])
      await region.getByRole('region', { name: 'Etapa ' + stage, exact: true }).waitFor()
    assert.ok(
      (await region
        .getByRole('region', { name: 'Etapa EX', exact: true })
        .getByRole('listitem')
        .count()) > 0,
    )
    await region
      .getByRole('region', { name: 'Etapa WB', exact: true })
      .getByText('Sin instrucción activa', { exact: true })
      .waitFor()
    const activityBox = await region
        .getByText('Actividad inferida del ciclo', { exact: true })
        .boundingBox(),
      regionBox = await region.boundingBox()
    await region.hover()
    await page.mouse.wheel(0, activityBox.y - regionBox.y - 12)
    await page.screenshot({ path: resolve(gui, '../build/debug-review-activity.png') })
    await bank.click()
    assert.equal(await bank.evaluate((n) => n.closest('details').open), true)
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await region.getByText('5', { exact: true }).first().waitFor()
    assert.equal(
      await bank.evaluate((n) => n.closest('details').open),
      true,
      'Capture update collapsed the user-opened register bank',
    )
    await until(() => page.getByRole('button', { name: 'Continuar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Continuar', exact: true }).click()
    await page.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
    await page
      .getByRole('tab', { name: 'Estado del procesador', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await menuCommand(page, 'Ver', 'Abrir vista de depuración')
    await page.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
    assert.equal(
      await bank.evaluate((n) => n.closest('details').open),
      false,
      'Stored/final view auto-expanded registers',
    )
    core.kill('SIGKILL')
    await region.getByText('Se perdió la conexión con el core', { exact: true }).waitFor()
    assert.equal(
      await bank.evaluate((n) => n.closest('details').open),
      false,
      'Stale view auto-expanded registers',
    )
    assert.equal(
      await globalState
        .getByRole('heading', { name: 'Estado global recibido', exact: true })
        .innerText(),
      'Estado global recibido',
    )
    await page.screenshot({ path: resolve(gui, '../build/debug-review-stale.png') })
    assert.deepEqual(errors, [])
    console.log(
      'Debug review passed: register bank collapsed, always-visible latches, instruction then source number, global state first and always visible, minimal chevrons, compact breakpoint choices with keyboard/outside dismissal and actual add/remove, semantic guide hierarchy and five activity stages. No fabricated initial capture. Isolated Electron/core and literal addition trace.',
    )
  } catch (e) {
    if (page && !page.isClosed())
      await page
        .screenshot({ path: resolve(gui, '../build/debug-review-failure.png') })
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
