// Debug visual review, comments 1–4: actual renderer and isolated core; no hardware acceptance.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const until = (predicate, timeout = 10000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'debug-spacing',
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
    const input = page.locator('.monaco-editor [role="textbox"]').first()
    await input.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# revisión visual\n')
    const dirty = page.getByRole('tab', { name: 'addition.s ●', exact: true })
    await dirty.waitFor()
    assert.equal(
      await dirty.locator('[data-modified=true]').evaluate((n) => getComputedStyle(n).color),
      'rgb(161, 92, 0)',
    )
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r4-modified.png') })
    const saved = resolve(root, 'saved.s')
    await instance.evaluate(({ dialog }, file) => {
      dialog.showSaveDialog = async () => ({ canceled: false, filePath: file })
    }, saved)
    await menuCommand(page, 'Archivo', 'Guardar como…')
    await page.getByRole('tab', { name: 'saved.s', exact: true }).waitFor()
    assert.equal(
      await page.locator('[data-modified=true]').count(),
      0,
      'Saved tab remains marked modified',
    )
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await page.getByRole('tab', { name: 'saved.s', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    assert.equal(await page.getByRole('tab', { name: 'saved.s', exact: true }).count(), 1)
    assert.equal(await page.getByRole('tab', { name: /FPGA/ }).count(), 0)
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
    const graph = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true }),
      inspector = graph.getByRole('region', { name: 'Inspector del circuito', exact: true })
    const follow = inspector.getByRole('button', { name: 'Seguir esta instrucción', exact: true }),
      component = inspector.getByLabel('Componente del circuito', { exact: true })
    await follow.waitFor()
    assert.equal(await follow.isDisabled(), true)
    assert.match(await follow.getAttribute('title'), /Avanzá un ciclo/)
    assert.equal(await follow.innerText(), '')
    assert.equal(
      await inspector.getByRole('button', { name: 'Centrar componente', exact: true }).innerText(),
      '',
    )
    await inspector.getByRole('img', { name: 'Observación fija', exact: true }).waitFor()
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
    assert.equal(await component.inputValue(), '')
    assert.match(await follow.getAttribute('title'), /Elegí IF\/ID, ID\/EX/)
    await component.selectOption('latch.if_id')
    await until(() => follow.isEnabled())
    await follow.click()
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    assert.equal(steps(), 1)
    for (const [cycle, latch] of [
      [2, 'latch.id_ex'],
      [3, 'latch.ex_mem'],
      [4, 'latch.mem_wb'],
    ]) {
      await step(cycle)
      await until(async () => (await component.inputValue()) === latch)
    }
    await inspector.getByRole('button', { name: 'Dejar de seguir', exact: true }).click()
    await inspector.getByRole('img', { name: 'Observación fija', exact: true }).waitFor()
    assert.equal(steps(), 4)
    await page.locator('.viewrv-breakpoint-slot').first().click()
    await page
      .getByRole('dialog', { name: /Breakpoint de la línea/ })
      .getByRole('button', { name: 'EX/MEM · entrada a MEM', exact: true })
      .click()
    await page.locator('.viewrv-breakpoint-targets-4').first().waitFor()
    async function gap(selector) {
      return page
        .locator(selector)
        .first()
        .evaluate((n) => {
          const style = getComputedStyle(n),
            label = getComputedStyle(n, '::before'),
            context = document.createElement('canvas').getContext('2d')
          context.font = label.fontWeight + ' ' + label.fontSize + ' ' + label.fontFamily
          const labelWidth = context.measureText(JSON.parse(label.content)).width
          context.font = style.fontWeight + ' ' + style.fontSize + ' ' + style.fontFamily
          return (
            n.getBoundingClientRect().width - labelWidth - context.measureText(n.textContent).width
          )
        })
    }
    const single = await gap('.viewrv-breakpoint-targets-4')
    assert.ok(single >= 5 && single <= 20, 'Excess/overlap in single target gutter: ' + single)
    await page.locator('.viewrv-breakpoint').first().click()
    await page
      .getByRole('dialog', { name: /Breakpoint de la línea/ })
      .getByRole('button', { name: 'IF/ID · entrada a ID', exact: true })
      .click()
    await page.locator('.viewrv-breakpoint-targets-5').first().waitFor()
    const multiple = await gap('.viewrv-breakpoint-targets-5')
    assert.ok(multiple >= 5 && multiple <= 20, 'Excess/overlap in multi-target gutter: ' + multiple)
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r4-follow.png') })
    await menuCommand(page, 'Ayuda', 'Catálogo de instrucciones')
    const catalog = page.getByRole('region', { name: 'Catálogo de instrucciones', exact: true })
    await catalog.getByText('33 de 33 instrucciones', { exact: true }).waitFor()
    const add = catalog.getByRole('article', { name: 'add', exact: true })
    await add.getByRole('heading', { name: 'add', level: 3, exact: true }).waitFor()
    const heading = add.getByRole('heading', { name: 'Parámetros', level: 4, exact: true }),
      example = add.getByRole('heading', { name: 'Ejemplo de uso', level: 4, exact: true })
    const h = await heading.boundingBox(),
      e = await example.boundingBox()
    assert.ok(Math.abs(h.x - e.x) < 1 && e.y > h.y, 'Narrow panel does not stack details')
    const anchors = await add.evaluate((n) =>
      [n.querySelector('h3'), n.querySelector('h4'), n.querySelector('p')].map(
        (e) => e.getBoundingClientRect().left,
      ),
    )
    assert.ok(Math.max(...anchors) - Math.min(...anchors) < 1, 'Catalog reading anchors differ')
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r4-catalog-narrow.png') })
    await page.setViewportSize({ width: 2400, height: 1000 })
    await until(async () => {
      const h = await heading.boundingBox(),
        e = await example.boundingBox()
      return e.x > h.x + 100 && Math.abs(h.y - e.y) < 1
    })
    await page.screenshot({ path: resolve(gui, '../build/debug-review-r4-catalog-wide.png') })
    await catalog.getByLabel('Buscar instrucción', { exact: true }).fill('lui')
    assert.equal(await catalog.getByRole('article').count(), 1)
    await catalog.getByText('lui x5, 0x12345', { exact: true }).waitFor()
    await catalog.getByLabel('Buscar instrucción', { exact: true }).fill('')
    await catalog.getByRole('button', { name: 'Memoria', exact: true }).click()
    assert.equal(await catalog.getByRole('article').count(), 8)
    assert.deepEqual(errors, [])
    console.log(
      'Round 4: measured compact single/multiple breakpoint gutters (' +
        single.toFixed(1) +
        '/' +
        multiple.toFixed(1) +
        'px); filename-only tabs; amber dirty title resets after saving; icon actions with contextual follow help and actual IF/ID→MEM/WB tracking without extra STEP; anchored responsive catalog with heading hierarchy, preserved search/filters/content. Literal UART fixture, isolated Electron/core.',
    )
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
