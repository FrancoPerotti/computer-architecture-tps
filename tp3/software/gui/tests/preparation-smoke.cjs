const { openConnection, closeConnection } = require('./ui-commands.cjs')
const { menuCommand } = require('./ui-commands.cjs')
// Actual Electron/CLI/core; only USB and programmer are injected in the test entry.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn, spawnSync } = require('node:child_process')
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
const gui = resolve(__dirname, '..'),
  tp3 = resolve(gui, '../..')
const root = mkdtempSync(resolve(tmpdir(), 'viewrv-pc04-gui-'))
const env = {
  ...process.env,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_DATA_HOME: resolve(root, 'data'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  PYTHONPATH: tp3,
  VIEWRV_TEST_CONTROL: root,
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
  const core = spawn(python, ['-m', 'software.tests.viewrv.preparation_core'], {
    cwd: tp3,
    env,
    stdio: ['ignore', 'ignore', 'pipe'],
  })
  let instance
  try {
    await eventually(() => existsSync(resolve(root, 'viewrv/core.json')))
    const discovery = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    const api = async (route, body, work) => {
      const response = await fetch(discovery.base_url + '/api/v1/' + route, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Authorization: 'Bearer ' + discovery.access_token,
          'Content-Type': 'application/json',
          ...(work ? { 'X-Viewrv-Work-Id': work } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      })
      const value = await response.json()
      assert.equal(value.error, null, JSON.stringify(value.error))
      return value.result
    }
    function cli(...args) {
      const result = spawnSync(python, ['-m', 'software.viewrv.cli', '--output', 'json', ...args], {
        cwd: root,
        env,
        encoding: 'utf8',
        timeout: 20000,
      })
      assert.equal(result.status, 0, result.stderr + result.stdout)
      return JSON.parse(result.stdout).result
    }
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
      env,
    })
    const page = await instance.firstWindow()
    await page.setViewportSize({ width: 1600, height: 1100 })
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
    await openConnection(page)
    await page.getByRole('button', { name: 'Actualizar destinos', exact: true }).click()
    await eventually(
      async () => (await page.getByLabel('Programador JTAG').locator('option').count()) === 2,
    )
    await page.getByLabel('Programador JTAG').selectOption('serial:210183TEST')
    await page.getByLabel('Puerto UART').selectOption('controlled-uart')
    writeFileSync(resolve(root, 'program.wait'), 'wait')
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await eventually(() => existsSync(resolve(root, 'program.entered')))
    await closeConnection(page)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Crear programa')
    const input = page.locator('.monaco-editor [role="textbox"]').first()
    await input.waitFor({ state: 'attached' })
    await input.focus()
    await page.keyboard.type('# edit while preparing')
    await page.keyboard.press('Enter')
    await eventually(async () =>
      (await api('program/list', undefined, observer)).programs[0].source_text.includes(
        'edit while preparing',
      ),
    )
    unlinkSync(resolve(root, 'program.wait'))
    await openConnection(page)
    await page
      .getByText('Programación confirmada. Comunicación UART comprobada en controlled-uart.', {
        exact: true,
      })
      .waitFor()
    await page.getByRole('button', { name: 'Desconectar UART', exact: true }).click()
    await page
      .getByText('UART desconectado. El trabajo continúa abierto.', { exact: true })
      .waitFor()
    await page.getByRole('button', { name: 'Conectar UART', exact: true }).click()
    await page
      .getByText('Comunicación UART comprobada en controlled-uart.', { exact: true })
      .waitFor()
    assert.equal(readFileSync(resolve(root, 'program.calls'), 'utf8'), 'program\n')
    writeFileSync(resolve(root, 'uart.fail'), 'fail')
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText('Comprobación UART', { exact: true }).waitFor()
    await page.getByText('Confirmada', { exact: true }).waitFor()
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i04-phases.png') })
    unlinkSync(resolve(root, 'uart.fail'))
    await page.getByRole('button', { name: 'Conectar UART', exact: true }).click()
    await page
      .getByText('Comunicación UART comprobada en controlled-uart.', { exact: true })
      .waitFor()
    await page.getByRole('button', { name: 'Guía de conexión y permisos', exact: true }).click()
    await page
      .frameLocator('iframe[title="Preparar el equipo y la Basys 3"]')
      .getByRole('heading', { name: 'Linux: acceso USB y serie', exact: true })
      .waitFor({ timeout: 10000 })
    await page.getByRole('button', { name: 'Cerrar guía', exact: true }).click()
    await page.getByRole('button', { name: 'Desconectar UART', exact: true }).click()
    await page
      .getByText('UART desconectado. El trabajo continúa abierto.', { exact: true })
      .waitFor()
    cli('board', 'prepare')
    await page
      .getByText('La placa está controlada por otro trabajo. Podés consultar su estado.', {
        exact: true,
      })
      .waitFor()
    await eventually(
      async () =>
        (await page
          .getByText('UART desconectado. El trabajo continúa abierto.', { exact: true })
          .count()) === 0,
    )
    assert.equal(
      await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).isDisabled(),
      true,
    )
    assert.equal(
      await page.getByRole('button', { name: 'Desconectar UART', exact: true }).isDisabled(),
      true,
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i04-owner.png') })
    assert.deepEqual(errors, [])
    const closed = page.waitForEvent('close', { timeout: 15000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    assert.equal(cli('board', 'status').connection_status, 'checked')
    assert.equal(cli('work', 'status').owns_board, true)
    cli('work', 'finish')
    await api('work/finish', {}, observer)
    await eventually(() => !existsSync(resolve(root, 'viewrv/core.json')))
    console.log(
      'PC-I04 GUI: selection, preparation while editing, phase confirmations, reconnect without programming, offline guide, foreign CLI ownership and close passed.',
    )
  } finally {
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
