// Debug visual review, comments 1–4: actual renderer and isolated core; no hardware acceptance.
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
    const title = await examples
        .getByRole('heading', { name: 'Abrir ejemplo', exact: true })
        .boundingBox(),
      search = await examples.getByLabel('Buscar ejemplo', { exact: true }).boundingBox(),
      entry = await examples
        .getByRole('button', { name: 'Sumar dos números', exact: true })
        .boundingBox()
    assert.ok(
      Math.abs(title.x - search.x) < 2 && Math.abs(search.x - entry.x) < 2,
      'Example modal left anchors differ',
    )
    await examples.getByLabel('Buscar ejemplo', { exact: true }).fill('suma')
    await examples.getByRole('button', { name: 'Sumar dos números', exact: true }).waitFor()
    await examples.getByLabel('Buscar ejemplo', { exact: true }).fill('')
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r5-examples.png') })
    await examples.getByRole('button', { name: 'Sumar dos números', exact: true }).click()
    await openConnection(page)
    const connection = page.getByRole('dialog', { name: 'Conexión con la placa', exact: true })
    const selects = await connection
      .locator('select')
      .evaluateAll((nodes) => nodes.map((n) => n.getBoundingClientRect().left))
    assert.equal(selects.length, 2)
    assert.ok(Math.abs(selects[0] - selects[1]) < 1, 'Board fields not aligned')
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r5-connection.png') })
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
    await component
      .getByRole('option', { name: 'Componente', exact: true })
      .waitFor({ state: 'attached' })
    assert.equal(await inspector.locator('label').count(), 0)
    assert.equal(await page.getByText(/Solo lectura durante la depuración/).count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Apariciones…', exact: true }).count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Breakpoints…', exact: true }).count(), 0)
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
    await step(1)
    const sourceFirst = page.getByRole('button', {
      name: 'Seguir instrucción de la línea 2',
      exact: true,
    })
    await sourceFirst.waitFor()
    const stageMargin = page.locator('.margin-view-overlays .viewrv-stage-line-margin').first()
    await stageMargin.waitFor()
    const margin = await stageMargin.evaluate((n) => ({
      width: n.getBoundingClientRect().width,
      full: n.closest('.margin').getBoundingClientRect().width,
      color: getComputedStyle(n).backgroundColor,
    }))
    assert.ok(
      Math.abs(margin.width - margin.full) < 1,
      'Pipeline highlight omits part of the margin',
    )
    assert.equal(
      margin.color,
      await page
        .locator('.viewrv-stage-line')
        .first()
        .evaluate((n) => getComputedStyle(n).backgroundColor),
    )
    const route = await sourceFirst.boundingBox(),
      stage = await page.locator('.viewrv-stage-badge').first().boundingBox()
    assert.ok(route.x >= stage.x + stage.width + 4, 'Source follow overlaps the stage badge')
    assert.ok(
      Math.abs(route.y + route.height / 2 - (stage.y + stage.height / 2)) < 3,
      'Source follow not anchored on its line',
    )
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
      'Round 5: no debug banner, no follow before capture, accessible inline Monaco follow after stage label, replacement and stop of a single occurrence without STEP, preserved keyboard inspection/breakpoints, narrow-split actions, removal after disconnection, component placeholder, aligned example/connection modal fields. Isolated core and literal addition trace.',
    )
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
