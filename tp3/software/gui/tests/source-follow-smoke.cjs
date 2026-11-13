// TEST-PC-005/018: follow one source occurrence at a time without implicit CPU steps.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const until = (predicate, timeout = 10000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'source-follow',
  async ({ root, gui, launch }) => {
    let { instance, page, errors } = await launch({
      viewport: { width: 1528, height: 771 },
      gpu: false,
    })
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    const examples = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
    await examples.getByLabel('Buscar ejemplo', { exact: true }).fill('suma')
    await examples.getByRole('button', { name: 'Sumar dos números', exact: true }).waitFor()
    await examples.getByLabel('Buscar ejemplo', { exact: true }).fill('')
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r5-examples.png') })
    await examples.getByRole('button', { name: 'Sumar dos números', exact: true }).click()
    await openConnection(page)
    const connection = page.getByRole('dialog', { name: 'Conexión con la placa', exact: true })
    await connection.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Más opciones de depuración', exact: true }).click()
    await page
      .getByRole('menuitem', { name: 'Depurar con diagrama interactivo', exact: true })
      .click()
    const graph = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true }),
      inspector = graph.getByRole('region', { name: 'Inspector del circuito', exact: true }),
      component = inspector.getByLabel('Componente del circuito', { exact: true })
    await graph.waitFor()
    assert.equal(await component.inputValue(), '')
    assert.equal(
      await page.getByRole('button', { name: /instrucción de la línea/ }).count(),
      0,
      'Follow offered before a received occurrence',
    )
    const steps = () =>
      readFileSync(resolve(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    async function step(cycle) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await graph.getByText(`Ciclo observado · ${cycle}`, { exact: true }).waitFor()
      assert.equal(steps(), cycle)
    }
    assert.equal(steps(), 0, 'Opening diagram debug emitted STEP')
    await until(() =>
      page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).isEnabled(),
    )
    await page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).click()
    await until(() =>
      page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).isEnabled(),
    )
    await graph
      .getByText('Sin captura completa. Los valores no se presumen cero.', { exact: true })
      .waitFor()
    assert.equal(steps(), 0, 'Restarting diagram debug emitted STEP')
    const wide = await page.locator('.monaco-editor .view-lines .view-line').first().innerText()
    await page.setViewportSize({ width: 1000, height: 771 })
    await until(
      async () =>
        (await page.locator('.monaco-editor .view-lines .view-line').first().innerText()) !== wide,
    )
    await page.setViewportSize({ width: 1528, height: 771 })
    await step(1)
    const sourceFirst = page.getByRole('button', {
      name: 'Seguir instrucción de la línea 2',
      exact: true,
    })
    await sourceFirst.waitFor()
    await sourceFirst.focus()
    await page.keyboard.press('Enter')
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    await page.locator('.margin-view-overlays .viewrv-selected-occurrence-line-margin').waitFor()
    await page
      .getByRole('button', { name: 'Dejar de seguir instrucción de la línea 2', exact: true })
      .waitFor()
    assert.equal(steps(), 1)
    await step(2)
    await page
      .getByRole('button', { name: 'Seguir instrucción de la línea 3', exact: true })
      .click()
    await until(async () => (await component.inputValue()) === 'latch.if_id')
    await page
      .getByRole('button', { name: 'Dejar de seguir instrucción de la línea 3', exact: true })
      .waitFor()
    assert.equal(
      await page.getByRole('button', { name: /^Dejar de seguir instrucción de la línea/ }).count(),
      1,
      'More than one source occurrence followed',
    )
    assert.equal(steps(), 2)
    await step(3)
    await until(async () => (await component.inputValue()) === 'latch.id_ex')
    assert.equal(
      await page
        .getByRole('button', { name: 'Dejar de seguir instrucción de la línea 2', exact: true })
        .count(),
      0,
    )
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r5-follow.png') })
    await page
      .getByRole('button', { name: 'Dejar de seguir instrucción de la línea 3', exact: true })
      .click()
    await inspector.getByRole('img', { name: 'Observación fija', exact: true }).waitFor()
    assert.equal(steps(), 3)
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
    await input.focus()
    await page.keyboard.press('Control+Home')
    await page.keyboard.press('ArrowDown')
    await page.keyboard.press('F9')
    await page.getByRole('dialog', { name: 'Breakpoint de la línea 2', exact: true }).waitFor()
    await page.keyboard.press('Escape')
    await input.focus()
    await page.keyboard.press('Control+Alt+F9')
    await page
      .getByRole('dialog', { name: 'Apariciones de la línea 2', exact: true })
      .getByRole('button', { name: 'Seleccionar EX/MEM', exact: true })
      .waitFor()
    await page.keyboard.press('Escape')
    await page.setViewportSize({ width: 900, height: 639 })
    const lineRoute = page.getByRole('button', {
      name: 'Seguir instrucción de la línea 3',
      exact: true,
    })
    await lineRoute.waitFor()
    const bounds = await lineRoute.boundingBox(),
      editorBounds = await page.locator('.monaco-editor:visible').first().boundingBox()
    assert.ok(
      bounds.x >= editorBounds.x && bounds.x + bounds.width <= editorBounds.x + editorBounds.width,
      'Source follow clipped in narrow split',
    )
    await lineRoute.click()
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r5-narrow.png') })
    await page.getByRole('button', { name: 'Desconectar', exact: true }).click()
    await until(
      async () =>
        (await page.getByRole('button', { name: /instrucción de la línea/ }).count()) === 0,
    )
    assert.equal(steps(), 3, 'Disconnection emitted STEP')
    assert.deepEqual(errors, [])
    console.log(
      'Source follow: diagram start/restart without STEP, wrapped source, single occurrence replacement, keyboard controls, narrow-split actions and disconnection. TEST-PC-005/018; controlled UART.',
    )
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
