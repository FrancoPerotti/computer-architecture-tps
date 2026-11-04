// Debug visual review, comments 1–4: actual renderer and isolated core; no hardware acceptance.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const until = (predicate, timeout = 10000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'debug-polish',
  async ({ root, gui, launch }) => {
    let { instance, page, errors } = await launch({
      viewport: { width: 1528, height: 771 },
      gpu: false,
    })
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    const chooser = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
    await chooser
      .getByRole('button', { name: 'Sumar dos números', exact: true })
      .getByText('addition.s', { exact: true })
      .waitFor()
    await chooser.getByRole('button', { name: 'Sumar dos números', exact: true }).click()
    await page.getByRole('tab', { name: 'addition.s', exact: true }).waitFor()
    const footer = page.locator('footer')
    await footer.getByRole('img', { name: 'Assembly', exact: true }).waitFor()
    await footer.getByRole('img', { name: 'Recuperación confirmada', exact: true }).waitFor()
    assert.equal(await footer.getByText('Recuperación confirmada', { exact: true }).count(), 0)
    await footer.getByText('addition.s', { exact: true }).waitFor()
    const connect = footer.getByRole('button', { name: 'Conectar', exact: true })
    assert.equal(await connect.innerText(), '')
    assert.equal(await connect.getAttribute('title'), 'Conectar')
    await connect.click()
    await page.getByRole('dialog', { name: 'Conexión con la placa', exact: true }).waitFor()
    await closeConnection(page)
    for (const name of ['IDE', 'Visor interactivo', 'Ajustes']) {
      const offset = await page.getByRole('button', { name, exact: true }).evaluate((n) => {
        const b = n.getBoundingClientRect(),
          s = n.querySelector('svg').getBoundingClientRect()
        return {
          x: Math.abs(b.x + b.width / 2 - s.x - s.width / 2),
          y: Math.abs(b.y + b.height / 2 - s.y - s.height / 2),
        }
      })
      assert.ok(offset.x < 1 && offset.y < 1, name + ' icon not centered')
    }
    const windowGap = await page
      .getByRole('button', { name: 'Maximizar o restaurar ventana', exact: true })
      .evaluate(
        (n) =>
          n.getBoundingClientRect().left - n.previousElementSibling.getBoundingClientRect().right,
      )
    assert.ok(windowGap <= 2)
    await instance.evaluate(({ dialog }) => {
      dialog.showSaveDialog = async (_, options) => {
        global.__polishDefaultSave = options.defaultPath
        return { canceled: true }
      }
    })
    await menuCommand(page, 'Archivo', 'Guardar como…')
    await until(
      async () => (await instance.evaluate(() => global.__polishDefaultSave)) === 'addition.s',
    )
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    assert.equal(
      await footer.getByRole('button', { name: 'Desconectar', exact: true }).innerText(),
      '',
    )
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await footer.getByRole('img', { name: 'Programa cargado en FPGA', exact: true }).waitFor()
    const steps = () =>
      readFileSync(resolve(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    await page.getByRole('button', { name: 'Más opciones de depuración', exact: true }).click()
    await page
      .getByRole('menuitem', { name: 'Depurar con diagrama interactivo', exact: true })
      .click()
    const diagram = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true })
    await diagram.waitFor()
    await diagram
      .getByText('Sin captura completa. Los valores no se presumen cero.', { exact: true })
      .waitFor()
    assert.equal(steps(), 0)
    assert.equal(
      await page.getByRole('region', { name: 'Estado del procesador', exact: true }).count(),
      0,
      'Diagram debug unexpectedly opened conventional results',
    )
    assert.equal(await diagram.getByText('Δ Cambios en amarillo', { exact: true }).count(), 0)
    assert.equal(await page.getByRole('tab', { name: 'addition.s', exact: true }).count(), 1)
    const wide = await page.locator('.monaco-editor .view-lines .view-line').first().innerText()
    await page.setViewportSize({ width: 1000, height: 771 })
    await until(
      async () =>
        (await page.locator('.monaco-editor .view-lines .view-line').first().innerText()) !== wide,
    )
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r3-wrap.png') })
    await page.setViewportSize({ width: 1528, height: 771 })
    await page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).click()
    await until(() =>
      page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).isEnabled(),
    )
    await diagram
      .getByText('Sin captura completa. Los valores no se presumen cero.', { exact: true })
      .waitFor()
    assert.equal(steps(), 0)
    await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).waitFor()
    await page.getByRole('tab', { name: 'Pipeline', exact: true }).getByTitle('Cerrar tab').click()
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    const results = page.getByRole('region', { name: 'Estado del procesador', exact: true })
    await results
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .waitFor()
    assert.equal(steps(), 0)
    for (let cycle = 1; cycle <= 4; cycle++) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await results.getByText(String(cycle), { exact: true }).first().waitFor()
    }
    const global = results.getByText('Estado global recibido', { exact: true }).locator('..')
    const sizes = await global
      .locator(':scope > div > div')
      .evaluateAll((nodes) => nodes.map((n) => n.getBoundingClientRect().height))
    assert.equal(sizes.length, 7)
    assert.ok(Math.max(...sizes) - Math.min(...sizes) < 1, 'Global cells differ in height')
    for (const latch of ['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB'])
      await results
        .getByRole('region', { name: `Registro ${latch}`, exact: true })
        .getByRole('img', { name: 'Instrucción válida', exact: true })
        .waitFor()
    assert.equal(
      await results.getByRole('button', { name: 'Abrir diagrama', exact: true }).count(),
      0,
    )
    assert.equal(await results.getByText(/Evidencia del ensayo/).count(), 0)
    assert.equal(await results.getByRole('button', { name: /^(Seleccionar|Seguir) / }).count(), 0)
    await page.locator('.viewrv-breakpoint-slot').first().click()
    await page
      .getByRole('dialog', { name: /Breakpoint de la línea/ })
      .getByRole('button', { name: 'ID/EX · entrada a EX', exact: true })
      .click()
    await page.locator('.viewrv-breakpoint-targets-2').waitFor()
    assert.equal(
      await page
        .locator('.viewrv-breakpoint-targets-2')
        .evaluate((n) => getComputedStyle(n, '::before').content),
      '"ID/EX"',
    )
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r3-state.png') })
    await page.locator('.viewrv-breakpoint').first().click()
    await page
      .getByRole('dialog', { name: /Breakpoint de la línea/ })
      .getByRole('button', { name: 'IF/ID · entrada a ID', exact: true })
      .click()
    await page.locator('.viewrv-breakpoint-targets-3').first().waitFor()
    assert.equal(
      await page
        .locator('.viewrv-breakpoint-targets-3')
        .first()
        .evaluate((n) => getComputedStyle(n, '::before').content),
      '"IF/ID · ID/EX"',
    )
    await until(() => page.getByRole('button', { name: 'Continuar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Continuar', exact: true }).click()
    await results.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
    await results
      .getByRole('region', { name: 'Registro IF/ID', exact: true })
      .getByRole('img', { name: 'Sin instrucción activa', exact: true })
      .waitFor()
    assert.deepEqual(errors, [])
    console.log(
      'Debug polish: filenames/save default; status/connect icons; centered navigation and compact window controls; diagram debug start/restart without STEP and conventional start; wrapping; equal global cells; validity/empty icons; no evidence/diagram/selection buttons; persistent multi-target breakpoint labels. Literal addition UART; no hardware acceptance.',
    )
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
