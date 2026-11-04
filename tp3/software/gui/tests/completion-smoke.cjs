const assert = require('node:assert/strict')
const { resolve } = require('node:path')
const { withGui, until } = require('./gui-fixture.cjs')
const { menuCommand } = require('./ui-commands.cjs')

withGui('completion', async ({ page, errors, gui }) => {
  await page.getByRole('button', { name: 'IDE', exact: true }).click()
  await menuCommand(page, 'Archivo', 'Crear programa')
  const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
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
    await until(
      async () =>
        (await docs.innerText()).includes(syntax) && (await docs.innerText()).includes('Ejemplo'),
    )
    assert.equal(await page.locator('.suggest-details .codicon-close:visible').count(), 0)
    await page.keyboard.press('Control+Space')
    await docs.waitFor()
    const bounds = await page.locator('.suggest-details:visible').boundingBox()
    assert.ok(
      bounds.x >= 0 &&
        bounds.x + bounds.width <= 1529 &&
        bounds.y >= 0 &&
        bounds.y + bounds.height <= 772,
      'Completion details overflow the viewport',
    )
    await page.keyboard.press('Escape')
  }
  await input.focus()
  await page.keyboard.press('Control+a')
  await page.keyboard.type('l')
  await page.keyboard.press('Control+Space')
  const docs = page.locator('.suggest-details .docs:visible')
  await docs.waitFor()
  const before = await docs.innerText()
  await page.keyboard.press('ArrowDown')
  await until(async () => (await docs.innerText()) !== before)
  await page.screenshot({ path: resolve(gui, '../build/stabilization-completion.png') })
  await page.keyboard.press('Escape')
  await page.keyboard.press('Control+Space')
  await docs.waitFor()
  assert.deepEqual(errors, [])
  console.log(
    'Pinned Monaco: rich documentation for LUI/store/HALT/shift/JALR, arrow navigation, Ctrl+Space cannot collapse it, Escape/reopen and viewport bounds passed. No widget methods replaced.',
  )
}).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
