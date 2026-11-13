// PC-I07: bank navigation and original-source guides, with a named literal UART trace.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const until = (predicate, timeout = 20000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'examples',
  async ({ root, gui, launch }) => {
    let { instance, page, errors } = await launch({
      viewport: { width: 1440, height: 1000 },
      gpu: false,
    })
    const external = []
    page.on('request', (request) => {
      if (!/^(viewrv:|blob:|data:|http:\/\/127\.0\.0\.1:)/.test(request.url()))
        external.push(request.url())
    })
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    const dialog = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
    await dialog.waitFor()
    await dialog.getByText('59 de 59 ejemplos', { exact: true }).waitFor()
    await dialog.getByLabel('Grupo de ejemplos', { exact: true }).selectOption('instruction')
    assert.equal(
      await dialog.getByRole('list', { name: 'Ejemplos disponibles' }).getByRole('button').count(),
      33,
    )
    await dialog.getByLabel('Buscar ejemplo', { exact: true }).fill('lb:')
    assert.equal(
      await dialog.getByRole('list', { name: 'Ejemplos disponibles' }).getByRole('button').count(),
      1,
    )
    await dialog.getByLabel('Buscar ejemplo', { exact: true }).fill('zz-no-example')
    await dialog.getByText('No hay ejemplos para esta búsqueda.', { exact: true }).waitFor()
    assert.equal(
      await dialog.getByRole('list', { name: 'Ejemplos disponibles' }).getByRole('button').count(),
      0,
    )
    await dialog.getByLabel('Buscar ejemplo', { exact: true }).fill('')
    await dialog.getByLabel('Grupo de ejemplos', { exact: true }).selectOption('boundary')
    assert.equal(
      await dialog.getByRole('list', { name: 'Ejemplos disponibles' }).getByRole('button').count(),
      8,
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-example-bank.png') })
    await dialog.getByLabel('Grupo de ejemplos', { exact: true }).selectOption('intro')
    await dialog.getByRole('button', { name: 'Sumar dos números', exact: true }).click()
    await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).click()
    await page.getByText('Esperado · diseño', { exact: true }).waitFor()
    await page.getByText('Guía por ciclo del ejemplo original', { exact: true }).click()
    await page
      .getByText('Se escribe x3=10 y termina el drenado de HALT.', { exact: true })
      .waitFor()
    assert.equal(
      await page.getByLabel('Guía del ciclo observado', { exact: true }).count(),
      0,
      'A guide fabricated an initial received capture',
    )
    const editor = page.locator('.monaco-editor [role="textbox"]').first()
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    await editor.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# variante educativa\n')
    await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).click()
    const modified = page.getByText(
      'Referencia del ejemplo original. Modificaste el programa; estos resultados esperados corresponden al código original.',
      { exact: true },
    )
    await modified.waitFor()
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-example-edited.png') })
    await page.getByRole('tab', { name: 'addition.s ●', exact: true }).click()
    // Undo restores the exact original. Reinserting text now triggers automatic formatting.
    for (
      let undo = 0;
      undo < 8 && !(await page.getByRole('tab', { name: 'addition.s', exact: true }).count());
      undo++
    )
      await menuCommand(page, 'Editar', 'Deshacer')
    await page.getByRole('tab', { name: 'addition.s', exact: true }).waitFor()
    await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).click()
    await until(async () => (await modified.count()) === 0)
    await page
      .getByRole('tab', { name: 'Acerca del ejemplo', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await page.getByRole('heading', { name: 'Listo para el primer ciclo', exact: true }).waitFor()
    const steps = () =>
      readFileSync(resolve(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    while (await page.getByRole('button', { name: 'Cerrar notificación', exact: true }).count())
      await page.getByRole('button', { name: 'Cerrar notificación', exact: true }).first().click()
    await page.getByText('Guía educativa del ejemplo', { exact: true }).click()
    assert.equal(steps(), 0)
    assert.equal(await page.getByLabel('Guía del ciclo observado', { exact: true }).count(), 0)
    for (let cycle = 1; cycle <= 7; cycle++) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await page
        .getByLabel('Guía del ciclo observado', { exact: true })
        .getByText(`Referencia para el ciclo ${cycle} · esperado`, { exact: true })
        .waitFor()
      assert.equal(steps(), cycle, 'Opening or updating a guide issued extra STEP')
      if (cycle === 5) {
        await page.getByLabel('Guía del ciclo observado', { exact: true }).scrollIntoViewIfNeeded()
        await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-example-cycle.png') })
      }
    }
    await page.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
    await page.getByLabel('Guía del ciclo observado', { exact: true }).scrollIntoViewIfNeeded()
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-example-received.png') })
    assert.deepEqual(errors, [])
    assert.deepEqual(external, [])
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    console.log(
      'PC-I07 example bank: 59 searchable programs, 33 individual instruction entries, boundary group, original guide, edited-source warning/restoration, no fabricated initial capture, seven received cycles and independent expected/received presentation passed. UART is the named literal addition fixture; no FPGA acceptance.',
    )
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
