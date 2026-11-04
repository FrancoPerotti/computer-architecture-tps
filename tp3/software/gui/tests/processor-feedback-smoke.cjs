const assert = require('node:assert/strict')
const { readFileSync, writeFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { withGui, until } = require('./gui-fixture.cjs')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
async function start(page) {
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
}
async function pauseFeedback(page) {
  await page.emulateMedia({ reducedMotion: 'no-preference' })
  await page.evaluate(() => {
    const animate = Element.prototype.animate
    Element.prototype.animate = function (frames, options) {
      const animation = animate.call(this, frames, options)
      if (['value-change', 'instruction-status'].includes(options?.id)) animation.pause()
      return animation
    }
  })
}
async function finishFeedback(page) {
  await page.evaluate(() =>
    document
      .getAnimations()
      .filter((a) => ['value-change', 'instruction-status'].includes(a.id))
      .forEach((a) => a.finish()),
  )
}
const countSteps = (root) =>
  readFileSync(resolve(root, 'uart.tx'), 'utf8')
    .split('\n')
    .filter((value) => value === '03').length
;(async () => {
  await withGui(
    'processor-feedback',
    async ({ page, root, gui, errors }) => {
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
      await page
        .getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
        .getByRole('button', { name: 'Sumar dos números', exact: true })
        .click()
      await start(page)
      await pauseFeedback(page)
      const results = page.getByRole('region', { name: 'Estado del procesador', exact: true }),
        global = results.getByRole('region', { name: 'Estado global recibido', exact: true })
      async function step(cycle) {
        await until(() =>
          page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
        )
        await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
        await until(() =>
          global
            .getByLabel('Formato de cycle_count', { exact: true })
            .evaluate(
              (n, expected) =>
                Number(n.parentElement.querySelector('code').textContent) === expected,
              cycle,
            ),
        )
        assert.equal(countSteps(root), cycle)
      }
      await step(1)
      assert.equal(await global.locator('details,summary').count(), 0)
      await global.getByRole('heading', { name: 'Estado global recibido', exact: true }).click()
      assert.equal(await global.getByLabel('Formato de pc', { exact: true }).isVisible(), true)
      assert.equal(await results.getByText(/valid=0: no hay una instrucción activa/).count(), 0)
      assert.equal(await results.getByLabel('Formato de PC de fetch', { exact: true }).count(), 0)
      await step(2)
      const cell = global.getByLabel('Formato de pc', { exact: true }).locator('..')
      await until(() =>
        cell.evaluate((n) =>
          n.getAnimations({ subtree: true }).some((a) => a.id === 'value-change'),
        ),
      )
      await cell.evaluate((n) => {
        const a = n.getAnimations({ subtree: true }).find((a) => a.id === 'value-change')
        a.currentTime = 120
      })
      const curtain = await cell.evaluate((n) => {
        const a = n.getAnimations({ subtree: true }).find((a) => a.id === 'value-change'),
          style = getComputedStyle(a.effect.target)
        return {
          scale: new DOMMatrix(style.transform).a,
          fill: style.backgroundColor,
          image: style.backgroundImage,
          text: n.querySelector('code').textContent,
        }
      })
      assert.ok(curtain.scale > 0 && curtain.scale < 1)
      assert.equal(curtain.fill, 'rgb(255, 243, 191)')
      assert.equal(curtain.image, 'none')
      assert.equal(curtain.text, '0x00000008')
      await page.screenshot({ path: resolve(gui, '../build/processor-feedback-curtain.png') })
      await finishFeedback(page)
      await step(3)
      await finishFeedback(page)
      await step(4)
      await finishFeedback(page)
      await step(5)
      await results
        .getByRole('region', { name: 'Registro IF/ID', exact: true })
        .getByRole('img', { name: 'Fallo de fetch', exact: true })
        .waitFor()
      await finishFeedback(page)
      await step(6)
      await until(() =>
        cell.evaluate(
          (n) =>
            n.dataset.changed === 'false' &&
            n.getAnimations({ subtree: true }).some((a) => a.id === 'value-change'),
        ),
      )
      assert.ok(
        await results
          .getByRole('region', { name: 'Registro IF/ID', exact: true })
          .evaluate((n) =>
            n.getAnimations({ subtree: true }).some((a) => a.id === 'instruction-status'),
          ),
        'Validity transition was not animated',
      )
      await page.emulateMedia({ reducedMotion: 'reduce' })
      await until(() =>
        page.evaluate(
          () =>
            document
              .getAnimations()
              .filter((a) => ['value-change', 'instruction-status'].includes(a.id)).length === 0,
        ),
      )
      assert.equal(
        await cell.evaluate((n) => getComputedStyle(n).backgroundColor),
        'rgb(240, 242, 245)',
      )
      await results.getByText('Guía educativa del ejemplo', { exact: true }).click()
      const guide = results.getByLabel('Referencia educativa del ejemplo', { exact: true })
      const expected = guide.getByRole('region', { name: 'Guía del ciclo observado', exact: true }),
        received = guide.getByRole('region', { name: 'Captura recibida del ejemplo', exact: true })
      const e = await expected.boundingBox(),
        r = await received.boundingBox()
      assert.ok(
        r.y > e.y + e.height && Math.abs(r.x - e.x) < 1,
        'Narrow guide must stack reference and capture',
      )
      await results.getByText('Actividad inferida del ciclo', { exact: true }).click()
      for (const stage of ['IF', 'ID', 'EX', 'MEM', 'WB'])
        await results
          .getByRole('region', { name: 'Etapa ' + stage, exact: true })
          .getByRole('heading')
          .waitFor()
      await results
        .getByLabel('Memoria observada', { exact: true })
        .locator(':scope > summary')
        .click()
      await results.getByRole('heading', { name: 'Sin datos de memoria', exact: true }).waitFor()
      await page.setViewportSize({ width: 900, height: 639 })
      assert.ok(
        await results.evaluate((n) => n.scrollWidth <= n.clientWidth + 1),
        'Processor content overflows a narrow split',
      )
      await global.scrollIntoViewIfNeeded()
      await page.screenshot({ path: resolve(gui, '../build/processor-feedback-narrow.png') })
      assert.equal(countSteps(root), 6)
      assert.deepEqual(errors, [])
    },
    { coreModule: 'educational_core', trace: 'addition' },
  )
  await withGui(
    'processor-memory',
    async ({ page, instance, root, gui, errors }) => {
      const source = resolve(root, 'memory.s')
      writeFileSync(source, 'sw x0,0(x0)\nsb x0,7(x0)\nlw x1,0(x0)\nhalt\n')
      await instance.evaluate(({ dialog }, path) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [path] })
      }, source)
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir programa…')
      await start(page)
      await pauseFeedback(page)
      const results = page.getByRole('region', { name: 'Estado del procesador', exact: true })
      for (let cycle = 1; cycle <= 5; cycle++) {
        await until(() =>
          page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
        )
        await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
        await until(() =>
          results
            .getByLabel('Formato de cycle_count', { exact: true })
            .evaluate(
              (n, expected) =>
                Number(n.parentElement.querySelector('code').textContent) === expected,
              cycle,
            ),
        )
        if (cycle < 5) await finishFeedback(page)
      }
      const fault = results.getByRole('region', { name: 'Registro IF/ID', exact: true })
      await fault.getByRole('img', { name: 'Fallo de fetch', exact: true }).waitFor()
      assert.ok(
        await fault.evaluate((n) =>
          n.getAnimations({ subtree: true }).some((a) => a.id === 'instruction-status'),
        ),
      )
      await finishFeedback(page)
      await results
        .getByLabel('Memoria observada', { exact: true })
        .locator(':scope > summary')
        .click()
      const filter = results.getByLabel('Filtrar dirección de memoria', { exact: true })
      await filter.fill('0x7')
      await results.getByLabel('Formato de mem[0x7]', { exact: true }).waitFor()
      assert.equal(await results.getByLabel('Formato de mem[0x0]', { exact: true }).count(), 0)
      await filter.fill('0xff')
      await results.getByRole('heading', { name: 'Sin coincidencias', exact: true }).waitFor()
      await results.getByRole('button', { name: 'Limpiar filtro de memoria', exact: true }).click()
      await results.getByLabel('Formato de mem[0x0]', { exact: true }).waitFor()
      await results.getByLabel('Formato de mem[0x7]', { exact: true }).waitFor()
      await filter.scrollIntoViewIfNeeded()
      await page.screenshot({ path: resolve(gui, '../build/processor-feedback-memory.png') })
      assert.equal(countSteps(root), 5)
      assert.deepEqual(errors, [])
    },
    { coreModule: 'educational_core', trace: 'memory' },
  )
  console.log(
    'Processor layout and feedback: fixed global state, no repeated fetch/empty prose, flat curtain in both directions, validity/fetch-fault transitions, immediate reduced-motion cancellation, stacked guide, stage hierarchy, memory empty/data/filter/reset and narrow layout. Eleven literal STEP captures; presentation sends none.',
  )
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
