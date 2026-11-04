const { waitForCore } = require('./ui-commands.cjs')
const { menuCommand } = require('./ui-commands.cjs')
// PC-I02: actual GUI and core, with a controlled assembler in the test-only core entry.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const {
  mkdtempSync,
  existsSync,
  readFileSync,
  rmSync,
  writeFileSync,
  unlinkSync,
} = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const gui = resolve(__dirname, '..')
const tp3 = resolve(gui, '../..')
const root = mkdtempSync(resolve(tmpdir(), 'viewrv-pc02-gui-'))
const environment = {
  ...process.env,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_DATA_HOME: resolve(root, 'data'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  PYTHONPATH: tp3,
  VIEWRV_TEST_ASSEMBLY_GATE: resolve(root, 'assembly.gate'),
}
const python = resolve(gui, '../.venv/bin/python')
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function eventually(predicate, timeout = 15000) {
  const deadline = Date.now() + timeout
  while (Date.now() < deadline) {
    try {
      if (await predicate()) return
    } catch {}
    await delay(30)
  }
  throw new Error('Condition was not satisfied within timeout')
}
;(async () => {
  let core = spawn(python, ['-m', 'software.tests.viewrv.controlled_core'], {
    cwd: tp3,
    env: environment,
    stdio: ['ignore', 'ignore', 'pipe'],
  })
  let instance
  try {
    await eventually(() => existsSync(resolve(root, 'viewrv/core.json')))
    let discovery = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    async function api(route, body, workId) {
      const response = await fetch(discovery.base_url + '/api/v1/' + route, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Authorization: 'Bearer ' + discovery.access_token,
          'Content-Type': 'application/json',
          ...(workId ? { 'X-Viewrv-Work-Id': workId } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      })
      const value = await response.json()
      if (value.error) throw new Error(JSON.stringify(value.error))
      return value.result
    }
    const cli = (await api('work/register', { client_type: 'cli' })).work_id
    const observer = (
      await api('work/register', {
        client_type: 'gui',
        registration_id: '11111111-2222-4333-8444-555555555555',
      })
    ).work_id
    instance = await electron.launch({
      executablePath: resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        gui,
        '--disable-gpu',
        '--ozone-platform=x11',
        `--user-data-dir=${resolve(root, 'profile')}`,
      ],
      env: environment,
    })
    const page = await instance.firstWindow()
    await page.setViewportSize({ width: 1440, height: 1000 })
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
    const assemblyRequests = []
    page.on('request', (req) => {
      if (req.url().endsWith('/program/assemble')) assemblyRequests.push(JSON.parse(req.postData()))
    })
    page.on('console', (message) => {
      if (message.type() === 'error') console.error(message.text())
    })
    await waitForCore(page)
    const connection = await page.evaluate(() => window.viewrvDesktop.getCoreConnection())
    assert.equal(connection.instance_id, discovery.instance_id)
    await instance.evaluate(({ dialog }, root) => {
      dialog.showSaveDialog = async () => ({ canceled: false, filePath: root + '/saved program.s' })
      dialog.showOpenDialog = async () => ({
        canceled: false,
        filePaths: [root + '/saved program.s'],
      })
    }, root)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Crear programa')
    const input = page.locator('.monaco-editor [role="textbox"]').first()
    await input.waitFor({ state: 'attached' })
    await input.focus()
    const started = Date.now()
    await page.keyboard.type('ad')
    const suggestions = page.locator('.suggest-widget').first()
    await suggestions.waitFor({ state: 'visible' })
    const names = await suggestions.locator('.label-name').allTextContents()
    assert.ok(names.includes('addi'))
    assert.ok(names.every((name) => name === name.toLowerCase()))
    await page.keyboard.press('Escape')
    await page.keyboard.press('Control+a')
    await page.keyboard.insertText('addi x1,x0,5\nhalt\n')
    const initialSource = 'addi x1,x0,5\n    halt\n    '
    await eventually(
      async () =>
        (await api('program/list', undefined, observer)).programs[0].source_text === initialSource,
    )
    await eventually(
      async () => (await page.getByLabel('Recuperación confirmada', { exact: true }).count()) > 0,
      2000,
    )
    console.log('GUI autosave observed within', Date.now() - started, 'ms')
    writeFileSync(resolve(root, 'assembly.gate'), 'wait')
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await page.getByText('Ensamblando…', { exact: true }).waitFor()
    await input.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.type('# edit while assembling')
    await page.keyboard.press('Enter')
    await eventually(async () =>
      (await api('program/list', undefined, observer)).programs[0].source_text.includes(
        '# edit while assembling',
      ),
    )
    unlinkSync(resolve(root, 'assembly.gate'))
    await page.getByText('Programa ensamblado', { exact: true }).waitFor()
    await menuCommand(page, 'Archivo', 'Guardar como…')
    await eventually(() => existsSync(resolve(root, 'saved program.s')))
    assert.equal(
      readFileSync(resolve(root, 'saved program.s'), 'utf8'),
      '    addi x1, x0, 5\n    halt\n    # edit while assembling\n',
    )
    await page
      .getByLabel(
        'El resultado corresponde a una revisión anterior; el texto actual se conserva.',
        { exact: true },
      )
      .waitFor()
    await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
    await eventually(
      async () => (await page.locator('.monaco-editor [role="textbox"]').count()) === 2,
    )
    const second = page.locator('.monaco-editor [role="textbox"]').nth(1)
    await second.focus()
    await page.keyboard.press('Control+Home')
    await page.keyboard.type('# shared model')
    await page.keyboard.press('Enter')
    await eventually(async () => {
      const programs = await api('program/list', undefined, observer)
      return (
        programs.programs.length === 1 &&
        programs.programs[0].source_text.startsWith('# shared model')
      )
    })
    await menuCommand(page, 'Archivo', 'Guardar')
    await eventually(() =>
      readFileSync(resolve(root, 'saved program.s'), 'utf8').startsWith('# shared model\n'),
    )
    await menuCommand(page, 'Archivo', 'Cerrar tab')
    await page.getByText('saved program.s', { exact: true }).first().click()
    await menuCommand(page, 'Archivo', 'Cerrar tab')
    await eventually(
      async () => (await api('program/list', undefined, observer)).programs[0].is_open === false,
    )
    await menuCommand(page, 'Archivo', 'Abrir programa…')
    await eventually(
      async () => (await page.locator('.monaco-editor [role="textbox"]').count()) === 1,
    )
    await input.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# reopened editor\n')
    await eventually(async () =>
      (await api('program/list', undefined, observer)).programs[0].source_text.endsWith(
        '# reopened editor\n',
      ),
    )
    await instance.evaluate(async ({ clipboard }) => {
      globalThis.__pc06Clipboard = await clipboard.readText()
      await clipboard.writeText('controlled clipboard sentinel')
    })
    await instance.evaluate(({ BrowserWindow }) => {
      const window = BrowserWindow.getAllWindows()[0]
      window.focus()
      window.webContents.focus()
    })
    const copySource = (await api('program/list', undefined, observer)).programs[0],
      copyExpected = copySource.source_text
    await menuCommand(page, 'Editar', 'Seleccionar todo')
    await menuCommand(page, 'Editar', 'Copiar')
    await eventually(
      () =>
        instance.evaluate(
          async ({ clipboard }, expected) => (await clipboard.readText()) === expected,
          copyExpected,
        ),
      5000,
    )
    await menuCommand(page, 'Archivo', 'Crear programa')
    await eventually(
      async () => (await page.locator('.monaco-editor [role="textbox"]').count()) === 2,
    )
    const editable = page.locator('.monaco-editor [role="textbox"]').last()
    await editable.focus()
    await menuCommand(page, 'Editar', 'Pegar')
    await eventually(async () =>
      (await api('program/list', undefined, observer)).programs.some(
        (program) =>
          program.program_id !== copySource.program_id && program.source_text === copyExpected,
      ),
    )
    const pasted = () =>
      api('program/list', undefined, observer).then((result) =>
        result.programs.find((program) => program.program_id !== copySource.program_id),
      )
    await menuCommand(page, 'Editar', 'Buscar')
    const find = page.getByPlaceholder('Buscar', { exact: true })
    await find.waitFor({ state: 'visible' })
    await find.fill('addi')
    await page.keyboard.press('Escape')
    assert.equal((await pasted()).source_text, copyExpected, 'Find edited the source')
    await menuCommand(page, 'Editar', 'Seleccionar todo')
    await menuCommand(page, 'Editar', 'Cortar')
    await eventually(async () => (await pasted()).source_text === '')
    await menuCommand(page, 'Editar', 'Deshacer')
    await eventually(async () => (await pasted()).source_text === copyExpected)
    await menuCommand(page, 'Editar', 'Rehacer')
    await eventually(async () => (await pasted()).source_text === '')
    await menuCommand(page, 'Editar', 'Pegar')
    await eventually(async () => (await pasted()).source_text === copyExpected)
    await instance.evaluate(async ({ clipboard }) => {
      await clipboard.writeText(globalThis.__pc06Clipboard)
      delete globalThis.__pc06Clipboard
    })
    await editable.focus()
    await page.keyboard.press('Control+a')
    await page.keyboard.type('invalid')
    await page.keyboard.press('Escape')
    await page.keyboard.press('Enter')
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await page
      .getByText('Instrucción inválida en el resultado controlado.', { exact: true })
      .first()
      .waitFor()
    const redSource = page.locator('.monaco-editor:visible .viewrv-source-error').first()
    await redSource.waitFor()
    assert.equal(
      await redSource.evaluate((node) => getComputedStyle(node).color),
      'rgb(186, 51, 72)',
    )
    assert.equal(
      await redSource.evaluate((node) => getComputedStyle(node).textDecorationLine),
      'none',
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-error.png') })
    await page
      .getByText('Instrucción inválida en el resultado controlado.', { exact: true })
      .first()
      .waitFor()
    await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
    await page
      .getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
      .getByRole('button', { name: 'Sumar dos números', exact: true })
      .click()
    // The intentional assembly failure creates a persistent notification.
    const notifications = page.getByRole('complementary', { name: 'Notificaciones', exact: true })
    await notifications.getByRole('alert').waitFor()
    const closeNotification = notifications.getByRole('button', {
      name: 'Cerrar notificación',
      exact: true,
    })
    while (await closeNotification.count()) await closeNotification.first().click()
    await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).click()
    await page.getByText(/Al finalizar, x1=8/).waitFor()
    await page.getByRole('tab', { name: 'addition.s', exact: true }).click()
    assert.equal(
      await page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled(),
      true,
    )
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    await page.getByLabel('Autor predeterminado').fill('Franco')
    await page.getByLabel('Autor predeterminado').blur()
    await eventually(async () => (await api('preferences')).preferences.default_author === 'Franco')
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page.screenshot({
      path: resolve(gui, `../build/${process.env.VIEWRV_EVIDENCE_PREFIX || 'gui-pc-i02'}.png`),
    })
    assert.equal(assemblyRequests[0].source_text, initialSource)
    assert.equal(assemblyRequests[1].source_text, 'invalid\n')
    assert.deepEqual(errors, [])
    const closed = page.waitForEvent('close', { timeout: 15000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    assert.equal(existsSync(resolve(root, 'viewrv/core.json')), true, 'GUI terminated the CLI work')
    await api('work/finish', {}, observer)
    await api('work/finish', {}, cli)
    await eventually(() => !existsSync(resolve(root, 'viewrv/core.json')))
    const recovery = resolve(root, 'data/viewrv/recovery')
    assert.equal(existsSync(recovery), true)
    await new Promise((resolve) =>
      core.exitCode !== null || core.signalCode !== null ? resolve() : core.once('exit', resolve),
    )
    const previousInstance = discovery.instance_id
    core = spawn(python, ['-m', 'software.tests.viewrv.controlled_core'], {
      cwd: tp3,
      env: environment,
      stdio: ['ignore', 'ignore', 'pipe'],
    })
    await eventually(() => existsSync(resolve(root, 'viewrv/core.json')))
    discovery = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    instance = await electron.launch({
      executablePath: resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        gui,
        '--disable-gpu',
        '--ozone-platform=x11',
        `--user-data-dir=${resolve(root, 'profile')}`,
      ],
      env: environment,
    })
    const reopened = await instance.firstWindow()
    reopened.on('pageerror', (error) => console.error('Reopened renderer:', String(error)))
    await waitForCore(reopened)
    const next = await reopened.evaluate(() => window.viewrvDesktop.getCoreConnection())
    assert.notEqual(next.instance_id, previousInstance)
    await reopened.getByRole('button', { name: 'IDE', exact: true }).click()
    try {
      await eventually(
        async () => (await reopened.locator('.monaco-editor [role="textbox"]').count()) > 0,
      )
    } catch (error) {
      console.log((await reopened.locator('body').innerText()).slice(0, 3000))
      await reopened.screenshot({ path: resolve(gui, '../build/gui-pc-i06-reopening-failure.png') })
      throw error
    }
    const nextObserver = (
      await api('work/register', {
        client_type: 'gui',
        registration_id: '22222222-2222-4333-8444-555555555555',
      })
    ).work_id
    const restored = await api('program/list', undefined, nextObserver)
    assert.equal(restored.programs.length, 3)
    assert.equal(
      restored.programs.every((program) => program.is_open),
      true,
    )
    assert.ok(restored.programs.some((program) => program.source_text.startsWith('# shared model')))
    await reopened.getByRole('button', { name: 'Ajustes', exact: true }).click()
    assert.equal(await reopened.getByLabel('Autor predeterminado').inputValue(), 'Franco')
    await api('work/finish', {}, nextObserver)
    const reopenedClosed = reopened.waitForEvent('close', { timeout: 15000 })
    await reopened.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await reopenedClosed
    await instance.close()
    instance = null
    await eventually(() => !existsSync(resolve(root, 'viewrv/core.json')))
    console.log(
      'PC-I02 GUI: editing, shared model, save, controlled assembly/diagnostic, examples, preferences, close and fresh-core reopening passed.',
    )
  } finally {
    if (instance)
      await instance
        .evaluate(async ({ clipboard }) => {
          if (typeof globalThis.__pc06Clipboard === 'string') {
            await clipboard.writeText(globalThis.__pc06Clipboard)
            delete globalThis.__pc06Clipboard
          }
        })
        .catch(() => {})
    if (instance) {
      await instance.evaluate(({ app }) => app.exit()).catch(() => {})
      await instance.close().catch(() => {})
    }
    if (core.exitCode === null && core.signalCode === null) core.kill('SIGTERM')
    await new Promise((resolve) => {
      if (core.exitCode !== null || core.signalCode !== null) resolve()
      else core.once('exit', resolve)
    })
    rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
