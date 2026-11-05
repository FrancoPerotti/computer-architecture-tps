// TEST-PC-002/010/017/020: document identity, recovery and tab/split lifecycle.
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { withGui, until } = require('./gui-fixture.cjs')
const { menuCommand } = require('./ui-commands.cjs')

withGui('editor-workspace', async ({ page, instance, root, errors }) => {
  await page.getByRole('button', { name: 'IDE', exact: true }).click()
  async function openExample(name = 'Sumar dos números') {
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    const chooser = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
    const item = chooser.getByRole('button', { name, exact: true })
    const filename = await item.locator('code').innerText()
    await item.click()
    await page.getByRole('tab', { name: filename, exact: true }).last().waitFor()
    return filename
  }
  async function recovery() {
    await menuCommand(page, 'Ver', 'Borradores recuperables…')
    return page.getByRole('dialog', { name: 'Borradores recuperables', exact: true })
  }
  for (const name of ['Sumar dos números', 'Sumar dos números', 'BNE: salto no tomado']) {
    const filename = await openExample(name)
    await page.getByRole('tab', { name: filename, exact: true }).getByTitle('Cerrar tab').click()
    await until(async () => (await page.getByRole('tab').count()) === 0)
  }
  const empty = await recovery()
  await empty.getByText('No hay borradores pendientes de recuperar.', { exact: true }).waitFor()
  await empty.getByRole('button', { name: 'Cerrar diálogo', exact: true }).click()

  await openExample()
  await instance.evaluate(({ dialog }) => {
    dialog.showSaveDialog = async (_, options) => {
      global.__defaultExamplePath = options.defaultPath
      return { canceled: true }
    }
  })
  await menuCommand(page, 'Archivo', 'Guardar como…')
  await until(
    async () => (await instance.evaluate(() => global.__defaultExamplePath)) === 'addition.s',
  )
  await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
  await page.getByText('Programa ensamblado', { exact: true }).waitFor()
  await page.getByRole('button', { name: 'Ver ensamblado', exact: true }).click()
  const row = page.getByRole('row').filter({ hasText: '0x00800093' })
  const cells = await row.getByRole('cell').allTextContents()
  assert.deepEqual(
    cells.map((text) => text.trim()),
    ['0x00000000', '2', 'addi x1, x0, 8', '0x00800093'],
  )
  await page
    .getByRole('tab', { name: 'Vista ensamblada', exact: true })
    .getByTitle('Cerrar tab')
    .click()

  // Closing the final view of a split returns its space to the surviving group.
  await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
  await until(async () => (await page.locator('.flexlayout__tabset_container').count()) === 2)
  await page
    .getByRole('tab', { name: 'addition.s', exact: true })
    .last()
    .getByTitle('Cerrar tab')
    .click()
  await until(async () => (await page.locator('.flexlayout__tabset_container').count()) === 1)

  // Each example's information belongs to its own group and keeps its context.
  await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).click()
  await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).waitFor()
  await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
  await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
  await openExample('Una dependencia entre instrucciones')
  await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).last().click()
  await until(
    async () =>
      (await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).count()) === 2,
  )
  assert.ok(
    await page
      .getByRole('tab', { name: 'dependency.s', exact: true })
      .evaluate((tab) =>
        [...tab.closest('.flexlayout__tabset_container').querySelectorAll('[role=tab]')].some(
          (sibling) => sibling.textContent.includes('Acerca del ejemplo'),
        ),
      ),
    'Example information opened outside its source group',
  )
  const dependency = page.getByRole('tab', { name: 'dependency.s', exact: true })
  await dependency.click()
  await dependency.getByTitle('Cerrar tab').click()
  while (await page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).count()) {
    const info = page.getByRole('tab', { name: 'Acerca del ejemplo', exact: true }).first()
    await info.click()
    await info.getByTitle('Cerrar tab').click()
  }
  while ((await page.getByRole('tab', { name: 'addition.s', exact: true }).count()) > 1) {
    const duplicate = page.getByRole('tab', { name: 'addition.s', exact: true }).last()
    await duplicate.click()
    await duplicate.getByTitle('Cerrar tab').click()
  }
  await until(async () => (await page.locator('.flexlayout__tabset_container').count()) === 1)

  await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
  const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
  await input.focus()
  await page.keyboard.press('Control+End')
  await page.keyboard.insertText('# conservar esta variante\n')
  await page
    .getByRole('tab', { name: 'addition.s ●', exact: true })
    .getByTitle('Cerrar tab')
    .click()
  await page.getByRole('tab', { name: 'addition.s ●', exact: true }).waitFor({ state: 'hidden' })
  await page.reload()
  await page.getByRole('button', { name: 'IDE', exact: true }).click()
  const drafts = await recovery()
  await until(async () => (await drafts.getByRole('button', { name: /^Recuperar / }).count()) === 1)
  await drafts.getByRole('button', { name: 'Recuperar addition.s', exact: true }).click()
  await until(async () =>
    (await page.locator('.monaco-editor:visible .view-lines').innerText())
      .replace(/\s/g, ' ')
      .includes('conservar esta variante'),
  )
  const saved = resolve(root, 'saved.s')
  await instance.evaluate(({ dialog }, file) => {
    dialog.showSaveDialog = async () => ({ canceled: false, filePath: file })
  }, saved)
  await menuCommand(page, 'Archivo', 'Guardar como…')
  await page.getByRole('tab', { name: 'saved.s', exact: true }).waitFor()
  assert.match(readFileSync(saved, 'utf8'), /# conservar esta variante/)
  assert.equal(await page.getByRole('tab', { name: /●/ }).count(), 0)
  assert.deepEqual(errors, [])
}).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
