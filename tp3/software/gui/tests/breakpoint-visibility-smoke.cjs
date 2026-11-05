// Breakpoints persist by source version, but are visible only while debug is open.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const until = (predicate, timeout = 10000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'breakpoint-visibility',
  async ({ root, gui, launch }) => {
    let { instance, page, errors } = await launch({
      viewport: { width: 1528, height: 771 },
      gpu: false,
    })
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
    const breakpointMarks = () =>
      editor.locator(
        '.viewrv-breakpoint, .viewrv-breakpoint-slot, [class*=viewrv-breakpoint-targets-]',
      )
    await loadDebug()
    assert.equal(steps(), 0)
    const arrow = page.getByRole('button', {
      name: 'Elegir registro del breakpoint de la línea 2',
      exact: true,
    })
    const picker = page.getByRole('dialog', { name: 'Breakpoint de la línea 2', exact: true })
    await arrow.click()
    await picker
      .getByRole('button', { name: 'IF/ID · entrada a ID', exact: true })
      .press('ArrowDown')
    assert.equal(
      await page.evaluate(() => document.activeElement.getAttribute('aria-label')),
      'ID/EX · entrada a EX',
    )
    await page.keyboard.press('Escape')
    await picker.waitFor({ state: 'hidden' })
    await arrow.click()
    await page.getByRole('heading', { name: 'Listo para el primer ciclo', exact: true }).click()
    await picker.waitFor({ state: 'hidden' })
    await arrow.click()
    await page
      .getByRole('dialog', { name: 'Breakpoint de la línea 2', exact: true })
      .getByRole('button', { name: 'EX/MEM · entrada a MEM', exact: true })
      .click()
    await editor.locator('.viewrv-breakpoint-targets-4').waitFor()
    await arrow.click()
    await picker.getByRole('button', { name: 'IF/ID · entrada a ID', exact: true }).click()
    await editor.locator('.viewrv-breakpoint-targets-5').waitFor()
    await arrow.click()
    const ifid = picker.getByRole('button', { name: 'IF/ID · entrada a ID', exact: true })
    assert.equal(await ifid.getAttribute('aria-pressed'), 'true')
    await ifid.click()
    await editor.locator('.viewrv-breakpoint-targets-4').waitFor()
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
    assert.deepEqual(errors, [])
    console.log(
      'Breakpoint visibility: explicit Stop removes dots, targets, empty slots, stage annotations and follow controls; gutter returns to editing width; same-version LOAD/debug and Restart preserve the breakpoint without extra STEP; editing after Stop stays clear. Isolated core, one literal UART capture.',
    )
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
