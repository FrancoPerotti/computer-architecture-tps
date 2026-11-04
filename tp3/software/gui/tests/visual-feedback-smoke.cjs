// Browser comments 1–27: actual renderer and isolated core; no hardware acceptance.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, closeConnection } = require('./ui-commands.cjs')
const until = (predicate, timeout = 10000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'visual-feedback',
  async ({ gui, launch }) => {
    let { instance, page, errors } = await launch({
      viewport: { width: 1301, height: 639 },
      gpu: false,
    })
    assert.equal(
      (await page.getByLabel('viewrv', { exact: true }).textContent()).replace(/\s/g, ''),
      'vrv',
    )
    assert.equal(
      await page
        .locator('main > header')
        .getByText('viewrv · Procesador RISC-V', { exact: true })
        .count(),
      0,
    )
    assert.equal(await page.getByRole('tab').count(), 0, 'Viewer must have no outer tab strip')
    assert.equal(await page.getByRole('dialog').count(), 0)
    assert.equal(
      await page.locator('footer').evaluate((n) => getComputedStyle(n).borderTopWidth),
      '0px',
    )
    const margin = await page
      .locator('iframe[title="Visor interactivo del pipeline"]')
      .evaluate((n) => window.innerWidth - n.getBoundingClientRect().right)
    assert.ok(margin >= 12, 'Floating surface touches window edge')
    await page.screenshot({ path: resolve(gui, '../build/visual-review-viewer.png') })
    await page.getByRole('button', { name: 'Conectar', exact: true }).click()
    await page.getByRole('dialog', { name: 'Conexión con la placa', exact: true }).waitFor()
    await closeConnection(page)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    const bank = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
    await bank.getByText('59 de 59 ejemplos', { exact: true }).waitFor()
    assert.equal(await bank.getByRole('radio').count(), 0)
    assert.equal(await bank.getByRole('button', { name: 'Abrir', exact: true }).count(), 0)
    assert.equal(
      await bank.getByLabel('Buscar ejemplo', { exact: true }).getAttribute('placeholder'),
      'Buscar ejemplo',
    )
    assert.equal(
      await bank
        .getByLabel('Grupo de ejemplos', { exact: true })
        .locator('option:checked')
        .innerText(),
      'Grupo',
    )
    assert.equal(await bank.evaluate((n) => getComputedStyle(n).overflow), 'hidden')
    await page.screenshot({ path: resolve(gui, '../build/visual-review-examples.png') })
    await bank.getByRole('button', { name: 'Sumar dos números', exact: true }).click()
    await page.getByRole('tab', { name: 'addition.s', exact: true }).waitFor()
    await until(() =>
      page
        .locator('.monaco-editor .view-lines')
        .innerText()
        .then((t) => t.includes('addi')),
    )
    assert.equal(await page.getByText('Recuperación confirmada', { exact: true }).count(), 0)
    const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
    await input.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# cambiado\n')
    await page.getByRole('tab', { name: 'addition.s ●', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).click()
    await page.getByText(/Referencia del ejemplo original. Modificaste/).waitFor()
    await until(() =>
      page
        .locator('.flexlayout__tabset_container')
        .count()
        .then((n) => n === 1),
    )
    assert.equal(
      await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).count(),
      1,
      'Guide is not a sibling tab',
    )
    await page.screenshot({ path: resolve(gui, '../build/visual-review-guide.png') })
    await page
      .getByRole('tab', { name: 'Acerca del ejemplo', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await until(() =>
      page
        .locator('.flexlayout__tabset_container')
        .count()
        .then((n) => n === 1),
    )
    // Restore the original through undo; inserting it would itself run automatic formatting.
    for (
      let undo = 0;
      undo < 8 && !(await page.getByRole('tab', { name: 'addition.s', exact: true }).count());
      undo++
    )
      await menuCommand(page, 'Editar', 'Deshacer')
    await page.getByRole('tab', { name: 'addition.s', exact: true }).waitFor()
    // Closed final tab in a duplicated source split must give its space back.
    await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
    await until(() =>
      page
        .locator('.flexlayout__tabset_container')
        .count()
        .then((n) => n === 2),
    )
    await page
      .getByRole('tab', { name: 'addition.s', exact: true })
      .last()
      .getByTitle('Cerrar tab')
      .click()
    await until(() =>
      page
        .locator('.flexlayout__tabset_container')
        .count()
        .then((n) => n === 1),
    )
    assert.equal(await page.getByRole('tab', { name: 'addition.s', exact: true }).count(), 1)
    // Outside debug the glyph gutter has no effect; source line hover remains visible.
    const editor = page.locator('.monaco-editor:visible').first()
    const eb = await editor.boundingBox()
    await page.mouse.click(eb.x + 10, eb.y + 30)
    assert.equal(await page.getByRole('dialog', { name: /Breakpoint de la línea/ }).count(), 0)
    await page.locator('.monaco-editor:visible .view-line').nth(1).hover()
    await page.locator('.viewrv-hover-line').waitFor()
    // Native completion details follow keyboard selection and escape panel clipping.
    await input.focus()
    await page.keyboard.press('Control+a')
    await page.keyboard.type('sl')
    await page.keyboard.press('Control+Space')
    const docs = page.locator('.suggest-details .docs:visible')
    await docs.waitFor()
    const firstDoc = await docs.innerText()
    assert.ok(firstDoc.length > 10)
    await page.keyboard.press('ArrowDown')
    await until(() => docs.innerText().then((t) => t.length > 10 && t !== firstDoc))
    const docBounds = await docs.boundingBox()
    assert.ok(docBounds.width >= 250, 'Suggestion documentation too narrow')
    assert.ok(
      await docs.evaluate(
        (n) =>
          n.getBoundingClientRect().bottom <=
          n.closest('.suggest-details').getBoundingClientRect().bottom + 1,
      ),
      'Documentation text is cut off inside its widget',
    )
    assert.ok(
      docBounds.x >= 0 &&
        docBounds.x + docBounds.width <= 1302 &&
        docBounds.y + docBounds.height <= 640,
      'Suggestion docs clipped by viewport',
    )
    await page.screenshot({ path: resolve(gui, '../build/visual-review-completion.png') })
    await page.keyboard.press('Escape')
    await page.setViewportSize({ width: 615, height: 639 })
    await input.focus()
    await page.keyboard.press('Control+a')
    await page.keyboard.type('lui')
    await page.keyboard.press('Control+Space')
    await docs.waitFor()
    await until(() => docs.innerText().then((t) => t.includes('20 bits')))
    assert.ok(
      await docs.evaluate((n) => {
        const r = n.getBoundingClientRect(),
          p = n.closest('.suggest-details').getBoundingClientRect()
        return (
          r.x >= 0 &&
          r.right <= window.innerWidth + 1 &&
          r.bottom <= p.bottom + 1 &&
          p.bottom <= window.innerHeight
        )
      }),
      'LUI documentation is clipped in a narrow window',
    )
    await page.screenshot({ path: resolve(gui, '../build/visual-review-completion-narrow.png') })
    await page.keyboard.press('Escape')
    await page.setViewportSize({ width: 1301, height: 639 })
    for (
      let undo = 0;
      undo < 8 && !(await page.getByRole('tab', { name: 'addition.s', exact: true }).count());
      undo++
    )
      await menuCommand(page, 'Editar', 'Deshacer')
    await page.getByRole('tab', { name: 'addition.s', exact: true }).waitFor()
    await menuCommand(page, 'Ayuda', 'Catálogo de instrucciones')
    await page.getByText('33 de 33 instrucciones', { exact: true }).waitFor()
    assert.equal(await page.getByRole('article').count(), 33)
    await page.getByLabel('Buscar instrucción', { exact: true }).fill('lui')
    assert.equal(await page.getByRole('article').count(), 1)
    await page.getByLabel('Buscar instrucción', { exact: true }).fill('')
    await page.getByRole('button', { name: 'Memoria', exact: true }).click()
    assert.equal(await page.getByRole('article').count(), 8)
    await page.screenshot({ path: resolve(gui, '../build/visual-review-catalog.png') })
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    const geometry = await page.evaluate(() => {
      const labels = [...document.querySelectorAll('label')].filter(
        (n) => n.offsetHeight && n.querySelector('input,select'),
      )
      const rows = labels.map((n) => {
        const r = n.getBoundingClientRect(),
          c = n.querySelector('input,select').getBoundingClientRect()
        return c.x > r.x + r.width / 2 && c.y >= r.y && c.bottom <= r.bottom
      })
      const note = [...document.querySelectorAll('p')].find((n) =>
        n.textContent.includes('Los cambios confirmados'),
      )
      return {
        rows,
        noteBottom: note.getBoundingClientRect().bottom,
        footerTop: document.querySelector('footer').getBoundingClientRect().top,
      }
    })
    assert.ok(geometry.rows.every(Boolean))
    assert.ok(geometry.noteBottom < geometry.footerTop)
    await page.screenshot({ path: resolve(gui, '../build/visual-review-settings.png') })
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page
      .getByRole('tab', { name: 'Catálogo de instrucciones', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await page
      .getByRole('tab', { name: 'addition.s', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await until(() =>
      page
        .getByRole('tab')
        .count()
        .then((n) => n === 0),
    )
    await menuCommand(page, 'Archivo', 'Crear programa')
    await page.getByRole('tab', { name: 'Sin título 1', exact: true }).waitFor()
    assert.deepEqual(errors, [])
    console.log(
      'Visual review passed: wordmark, viewer, floating connection, direct examples, original/modified titles, sibling about tab, collapse empty splits, inactive gutter, line hover, expanded keyboard completion docs, searchable catalog, settings layout and footer. 1301×639; source Electron, isolated controlled core.',
    )
  },
  { coreModule: 'session_core' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
