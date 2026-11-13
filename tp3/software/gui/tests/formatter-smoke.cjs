const assert = require('node:assert/strict')
const { readFileSync, writeFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { randomUUID } = require('node:crypto')
const { withGui, until } = require('./gui-fixture.cjs')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')

withGui(
  'formatter',
  async ({ page, instance, root, gui, errors }) => {
    const original =
      '# Comentario, sin cambios\nStart : addi\tx1 ,x0, 8\n addi x2,x0,2\n\tadd x3 , x1,x2\n halt\n'
    const formatted =
      '# Comentario, sin cambios\nStart: addi x1, x0, 8\n    addi x2, x0, 2\n    add x3, x1, x2\n    halt\n'
    const path = resolve(root, 'formatter.s')
    writeFileSync(path, original)
    await instance.evaluate(({ dialog }, path) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [path] })
    }, path)
    const discovery = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    let observer
    async function api(route, body) {
      const response = await fetch(discovery.base_url + '/api/v1/' + route, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Authorization: 'Bearer ' + discovery.access_token,
          'Content-Type': 'application/json',
          ...(observer ? { 'X-Viewrv-Work-Id': observer } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      })
      const value = await response.json()
      assert.equal(value.error, null)
      return value.result
    }
    observer = (await api('work/register', { client_type: 'gui', registration_id: randomUUID() }))
      .work_id
    try {
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir programa…')
      const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
      await input.waitFor()
      const program = async () =>
        (await api('program/list')).programs.find(
          (p) => p.path === path || p.source_text.includes('Start'),
        )
      const expectSource = (text) => until(async () => (await program())?.source_text === text)
      await expectSource(original)
      await input.focus()
      await page.keyboard.press('Control+End')
      await menuCommand(page, 'Editar', 'Formatear documento')
      await expectSource(formatted)
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      await menuCommand(page, 'Editar', 'Rehacer')
      await expectSource(formatted)
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      await input.focus()
      await page.keyboard.press('Alt+Shift+f')
      await expectSource(formatted)
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      await input.focus()
      await page.keyboard.press('Control+Shift+i')
      await expectSource(formatted)
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
      await until(
        async () => (await page.locator('.monaco-editor:visible [role="textbox"]').count()) === 2,
      )
      await page.locator('.monaco-editor:visible [role="textbox"]').last().focus()
      await menuCommand(page, 'Editar', 'Formatear documento')
      await expectSource(formatted)
      for (const editor of await page.locator('.monaco-editor:visible').all())
        assert.ok(
          (await editor.locator('.view-line').allTextContents()).some((line) =>
            line.replace(/\u00a0/g, ' ').includes('    add x3, x1, x2'),
          ),
        )
      await menuCommand(page, 'Archivo', 'Guardar')
      await until(() => readFileSync(path, 'utf8') === formatted)
      await page.screenshot({ path: resolve(gui, '../build/formatter-document.png') })
      // Use deliberately unformatted text to prove formatting cannot edit the protected model.
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      // Save formats before capturing the revision written to disk (menu and shortcut).
      await menuCommand(page, 'Archivo', 'Guardar')
      await expectSource(formatted)
      await until(() => readFileSync(path, 'utf8') === formatted)
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      await input.focus()
      await page.keyboard.press('Control+s')
      await expectSource(formatted)
      await until(() => readFileSync(path, 'utf8') === formatted)
      await menuCommand(page, 'Editar', 'Deshacer')
      await expectSource(original)
      // Real paste invokes only the range formatter, including undo and clipboard restoration.
      const clipboard = await instance.evaluate(({ clipboard }) => clipboard.readText())
      try {
        await instance.evaluate(({ clipboard }, source) => clipboard.writeText(source), original)
        await input.focus()
        await page.keyboard.press('Control+a')
        await page.keyboard.press('Control+v')
        await expectSource(formatted)
        await menuCommand(page, 'Editar', 'Deshacer')
        await expectSource(original)
      } finally {
        await instance.evaluate(({ clipboard }, text) => clipboard.writeText(text), clipboard)
      }
      // Keystrokes do not format unfinished code; Enter formats just the completed line.
      await input.focus()
      await page.keyboard.press('Control+End')
      await page.keyboard.type('addi x4,x0,4')
      await expectSource(original + 'addi x4,x0,4')
      await page.keyboard.press('Escape')
      await page.keyboard.press('Enter')
      await expectSource(original + '    addi x4, x0, 4\n    ')
      await page.keyboard.type('h')
      await expectSource(original + '    addi x4, x0, 4\n    h')
      // Restore the file explicitly, without relying on how typing is grouped in undo.
      await page.keyboard.press('Escape')
      await page.keyboard.press('Control+a')
      await page.keyboard.insertText(original.slice(0, -1))
      await until(async () => {
        const source = (await program()).source_text
        return source.endsWith('halt') && !source.includes('addi x4')
      })
      const protectedSource = (await program()).source_text
      assert.ok(protectedSource.includes('Start :'), 'Protection test needs unformatted source')
      await openConnection(page)
      await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
      await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
      await closeConnection(page)
      await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
      await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
      await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
      await page.getByRole('button', { name: 'Cargar', exact: true }).click()
      await until(() =>
        page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
      await page.getByRole('heading', { name: 'Listo para el primer ciclo', exact: true }).waitFor()
      await input.focus()
      await page.keyboard.press('Alt+Shift+f')
      await page.keyboard.press('Control+Shift+i')
      await page.getByRole('button', { name: 'Editar', exact: true }).click()
      assert.equal(
        await page.getByRole('menuitem', { name: 'Formatear documento', exact: true }).isDisabled(),
        true,
      )
      await page.keyboard.press('Escape')
      assert.equal((await program()).source_text, protectedSource)
      assert.equal(
        readFileSync(resolve(root, 'uart.tx'), 'utf8')
          .split('\n')
          .filter((value) => value === '03').length,
        0,
      )
      assert.deepEqual(errors, [])
      console.log(
        'Formatter: real menu, both shortcuts, undo/redo, shared split, automatic save/paste/Enter, unfinished typing, protected debug source and no STEP passed.',
      )
    } finally {
      await api('work/finish', {})
    }
  },
  { coreModule: 'educational_core', trace: 'addition' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
