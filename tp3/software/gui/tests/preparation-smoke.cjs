// Actual Electron/CLI/core; only USB and programmer are injected in the test entry.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { openConnection, closeConnection } = require('./ui-commands.cjs')
const { menuCommand } = require('./ui-commands.cjs')
const { spawnSync } = require('node:child_process')
const { existsSync, readFileSync, writeFileSync, unlinkSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const eventually = (predicate, timeout = 15000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'preparation',
  async ({ root, gui, python, env, launch }) => {
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
    let { instance, page, errors } = await launch({
      viewport: { width: 1600, height: 1100 },
      gpu: false,
    })
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
    console.log(
      'PC-I04 GUI: selection, preparation while editing, phase confirmations, reconnect without programming, offline guide, foreign CLI ownership and close passed.',
    )
  },
  { coreModule: 'preparation_core' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
