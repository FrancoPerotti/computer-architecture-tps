// Third visual review, comments 1–8: actual renderer and isolated core; no hardware acceptance.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand } = require('./ui-commands.cjs')
const until = (predicate, timeout = 10000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'visual-round3',
  async ({ gui, launch }) => {
    let { instance, page, errors } = await launch({
      viewport: { width: 1301, height: 639 },
      gpu: false,
    })
    assert.equal(
      (await page.getByLabel('viewrv', { exact: true }).textContent()).replace(/\s/g, ''),
      'vrv',
    )
    const title = page.locator('main > header').getByText('viewrv', { exact: true })
    assert.ok(await title.isVisible())
    assert.ok(
      await title.evaluate((n) => {
        const r = n.getBoundingClientRect()
        return Math.abs(r.x + r.width / 2 - window.innerWidth / 2) < 1
      }),
    )
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    async function openExample(name) {
      await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
      const dialog = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
      const filename = await dialog
        .getByRole('button', { name, exact: true })
        .locator('code')
        .innerText()
      await dialog.getByRole('button', { name, exact: true }).click()
      await page.getByRole('tab', { name: filename, exact: true }).last().waitFor()
    }
    function centered(node) {
      const a = node.getBoundingClientRect(),
        b = node.querySelector('svg').getBoundingClientRect()
      return (
        Math.abs(a.x + a.width / 2 - b.x - b.width / 2) < 1 &&
        Math.abs(a.y + a.height / 2 - b.y - b.height / 2) < 1
      )
    }
    await openExample('Sumar dos números')
    const info = page.getByRole('button', { name: 'Acerca del ejemplo', exact: true })
    await info.waitFor()
    assert.ok(await info.evaluate(centered), 'Information icon is off-center')
    const dropdown = page.getByRole('button', { name: 'Más opciones de ejecución', exact: true })
    assert.ok(await dropdown.evaluate(centered), 'Run chevron is off-center')
    await dropdown.hover()
    assert.ok(await dropdown.evaluate(centered), 'Run chevron shifts on hover')
    await until(
      async () =>
        (await dropdown.evaluate((n) => getComputedStyle(n).backgroundColor)) ===
        'rgb(228, 231, 238)',
    )
    await page.screenshot({ path: resolve(gui, '../build/visual-round3-controls.png') })
    await info.click()
    await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).waitFor()
    assert.equal(
      await page.locator('.flexlayout__tabset_container').count(),
      1,
      'About created a split',
    )
    assert.equal(
      await page.locator('.monaco-editor:visible [role="textbox"]').count(),
      0,
      'About is not a sibling tab',
    )
    await page.getByText('Preparar dos operandos y sumar sus valores.', { exact: true }).waitFor()
    await page
      .getByRole('tab', { name: 'Acerca del ejemplo', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
    await openExample('Una dependencia entre instrucciones')
    await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).last().click()
    await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).waitFor()
    const sourceGroup = await page
      .getByRole('tab', { name: 'dependency.s', exact: true })
      .evaluate((n) => n.closest('.flexlayout__tabset_container').getBoundingClientRect().x)
    const infoGroup = await page
      .getByRole('tab', { name: 'Acerca del ejemplo', exact: true })
      .evaluate((n) => n.closest('.flexlayout__tabset_container').getBoundingClientRect().x)
    assert.equal(sourceGroup, infoGroup, 'About opened outside the source group')
    assert.equal(await page.locator('.flexlayout__tabset_container').count(), 2)
    await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).first().click()
    assert.equal(
      await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).count(),
      2,
      'About retargeted a different example',
    )
    await page.screenshot({ path: resolve(gui, '../build/visual-round3-about.png') })
    await page.getByRole('tab', { name: 'addition.s', exact: true }).first().click()
    const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
    await page.setViewportSize({ width: 1528, height: 771 })
    for (const [mnemonic, syntax] of [
      ['lui', 'lui rd, imm20'],
      ['sw', 'sw rs2, offset(rs1)'],
      ['halt', 'halt'],
      ['slli', 'slli rd, rs1, shamt'],
      ['jalr', 'jalr rd, offset(rs1)'],
    ]) {
      await input.focus()
      await page.keyboard.press('Control+a')
      await page.keyboard.type(mnemonic)
      await page.keyboard.press('Control+Space')
      const docs = page.locator('.suggest-details .docs:visible')
      await docs.waitFor()
      await until(() => docs.innerText().then((t) => t.includes(syntax) && t.includes('Ejemplo')))
      assert.ok(await docs.getByText('Parámetros', { exact: true }).isVisible())
      assert.equal(await page.locator('.suggest-details [role="button"]:visible').count(), 0)
      const bounds = await page.locator('.suggest-details:visible').boundingBox()
      assert.ok(
        bounds.x >= 0 &&
          bounds.x + bounds.width <= 1529 &&
          bounds.y >= 0 &&
          bounds.y + bounds.height <= 772,
        'Rich completion overflows viewport',
      )
      if (mnemonic === 'lui')
        await page.screenshot({ path: resolve(gui, '../build/visual-round3-completion.png') })
      await page.keyboard.press('Escape')
    }
    await menuCommand(page, 'Ayuda', 'Catálogo de instrucciones')
    await page.getByText('33 de 33 instrucciones', { exact: true }).waitFor()
    const articles = page.getByRole('article')
    assert.equal(await articles.count(), 33)
    assert.ok(
      await articles.evaluateAll((ns) =>
        ns.slice(1).every((n, i) => {
          const a = ns[i].getBoundingClientRect(),
            b = n.getBoundingClientRect()
          return Math.abs(a.x - b.x) < 1 && b.y >= a.bottom
        }),
      ),
      'Catalog entries are not arranged in one list',
    )
    const add = page.getByRole('article', { name: 'add', exact: true })
    await add.getByText('add rd, rs1, rs2', { exact: true }).waitFor()
    await add.getByRole('heading', { name: 'Ejemplo de uso', exact: true }).waitFor()
    await page.getByLabel('Buscar instrucción', { exact: true }).fill('lui')
    assert.equal(await articles.count(), 1)
    const lui = page.getByRole('article', { name: 'lui', exact: true })
    await lui.getByText('lui rd, imm20', { exact: true }).waitFor()
    await lui.getByText('lui x5, 0x12345', { exact: true }).waitFor()
    await lui.getByText(/Campo de 20 bits sin signo/).waitFor()
    await page.screenshot({ path: resolve(gui, '../build/visual-round3-catalog-lui.png') })
    await page.getByLabel('Buscar instrucción', { exact: true }).fill('')
    await page.screenshot({ path: resolve(gui, '../build/visual-round3-catalog.png') })
    assert.deepEqual(errors, [])
    console.log(
      'Round 3 passed: compact v|rv and centered product title; centered info/Run icons including hover; about tabs in the source group with independent example context; rich completion for LUI, stores, HALT, shifts and JALR; all 33 catalog entries as a single list with syntax, operands and examples. Isolated Electron/core; no FPGA acceptance.',
    )
  },
  { coreModule: 'session_core' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
