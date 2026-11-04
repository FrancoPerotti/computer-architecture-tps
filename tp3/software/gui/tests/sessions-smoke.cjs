// PC-I05: real GUI and CLI share core sessions; controlled UART is test-only.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { openConnection, closeConnection } = require('./ui-commands.cjs')
const { menuCommand } = require('./ui-commands.cjs')
const { spawn, spawnSync } = require('node:child_process')
const { readFileSync, writeFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { randomUUID } = require('node:crypto')
const assert = require('node:assert/strict')
const until = (predicate, timeout = 18000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'sessions',
  async ({ root, gui, python, env, launch }) => {
    const discovery = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    const source = resolve(root, 'exact source.s')
    writeFileSync(source, 'addi x1,x0,5\nhalt\n')
    async function api(route, body, owner) {
      const response = await fetch(discovery.base_url + '/api/v1/' + route, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Authorization: 'Bearer ' + discovery.access_token,
          'Content-Type': 'application/json',
          ...(owner ? { 'X-Viewrv-Work-Id': owner } : {}),
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
        maxBuffer: 32 * 1024 * 1024,
      })
      assert.equal(
        result.status,
        0,
        String(result.error || '') + result.stdout.slice(0, 2000) + result.stderr.slice(0, 2000),
      )
      return JSON.parse(result.stdout).result
    }
    cli('board', 'prepare')
    cli('program', 'assemble', source)
    cli('program', 'load', source)
    const opened = cli('debug', 'start')
    cli('debug', 'breakpoint', 'add', '--pc', '0', '--latch', 'IF/ID')
    const first = cli('debug', 'continue')
    assert.equal(first.last_step.step_index, 1)
    let { instance, page, errors } = await launch({
      viewport: { width: 1440, height: 1000 },
      gpu: false,
    })
    await openConnection(page)
    await page
      .getByText('La placa está controlada por otro trabajo. Podés consultar su estado.', {
        exact: true,
      })
      .waitFor()
    assert.equal(
      await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).isDisabled(),
      true,
    )
    await closeConnection(page)
    // Find the real window's work through an independent, finite SSE observer.
    const probe = (
      await api('work/register', { client_type: 'gui', registration_id: randomUUID() })
    ).work_id
    const stream = await fetch(discovery.base_url + '/api/v1/events', {
      headers: { Authorization: 'Bearer ' + discovery.access_token, 'X-Viewrv-Work-Id': probe },
    })
    const reader = stream.body.getReader()
    let buffer = '',
      state
    while (!state) {
      const chunk = await reader.read()
      assert.equal(chunk.done, false)
      buffer += Buffer.from(chunk.value).toString('utf8')
      const line = buffer
        .split('\n')
        .slice(0, -1)
        .find((line) => line.startsWith('data: '))
      if (line) state = JSON.parse(line.slice(6))
    }
    await reader.cancel()
    const guiWork = state.data.works.find(
      (work) => work.client_type === 'gui' && work.work_id !== probe,
    ).work_id
    const live = state.data.sessions.find((session) => session.session_id === opened.session_id)
    assert.deepEqual(live.last_observation, first.last_step)
    assert.equal(live.source_text, 'addi x1,x0,5\nhalt\n')
    await api('work/finish', {}, probe)
    const before = readFileSync(resolve(root, 'uart.tx'), 'utf8')
    const shown = await page.evaluate(
      async ({ discovery, guiWork, identity }) => {
        const response = await fetch(
          discovery.base_url + '/api/v1/session/show?session_id=' + identity,
          {
            headers: {
              Authorization: 'Bearer ' + discovery.access_token,
              'X-Viewrv-Work-Id': guiWork,
            },
          },
        )
        return await response.json()
      },
      { discovery, guiWork, identity: opened.session_id },
    )
    assert.equal(shown.error, null)
    assert.deepEqual(shown.result.last_observation, first.last_step)
    assert.equal(
      readFileSync(resolve(root, 'uart.tx'), 'utf8'),
      before,
      'GUI observation sent UART',
    )
    await instance.evaluate(({ dialog }, source) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [source] })
    }, source)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir programa…')
    await page.getByRole('img', { name: 'Solo lectura', exact: true }).waitFor()
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i05-source-protected.png') })
    const protectedInput = page.locator('.monaco-editor [role="textbox"]').first()
    await protectedInput.waitFor({ state: 'attached' })
    await protectedInput.focus()
    await page.keyboard.type('# forbidden edit')
    assert.equal(
      (await api('session/show?session_id=' + opened.session_id)).source_text,
      'addi x1,x0,5\nhalt\n',
    )
    await menuCommand(page, 'Archivo', 'Crear programa')
    const editable = page.locator('.monaco-editor [role="textbox"]').last()
    await editable.waitFor({ state: 'attached' })
    cli('debug', 'breakpoint', 'remove', '--pc', '0', '--latch', 'IF/ID')
    continuing = spawn(
      python,
      ['-m', 'software.viewrv.cli', '--output', 'json', 'debug', 'continue'],
      { cwd: root, env, stdio: ['ignore', 'pipe', 'pipe'] },
    )
    await until(async () =>
      (await api('work/cli/status')).pending_commands.includes('debug continue'),
    )
    await editable.focus()
    await page.keyboard.type('# editable while CLI continues')
    await page.keyboard.press('Enter')
    await until(async () =>
      (await api('program/list', undefined, guiWork)).programs.some((program) =>
        program.source_text.includes('editable while CLI continues'),
      ),
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i05-protection.png') })
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    const cliState = cli('work', 'status')
    assert.equal(cliState.debug_open, true)
    assert.equal(cliState.owns_board, true)
    assert.equal(continuing.exitCode, null, 'Closing observer stopped CLI continue')
    const paused = cli('debug', 'pause')
    assert.ok(paused.last_step.step_index > 1)
    await new Promise((resolve, reject) => {
      if (continuing.exitCode !== null) return resolve()
      continuing.once('exit', (code) =>
        code === 0 ? resolve() : reject(new Error('Continue failed ' + code)),
      )
    })
    cli('debug', 'stop')
    const logs = cli('session', 'logs')
    assert.equal(logs.record_status, 'complete')
    cli('work', 'finish')
    assert.deepEqual(errors, [])
    console.log(
      'PC-I05 GUI: CLI controls, SSE/HTTP preserve source and capture, protected source and independent editing work, closing GUI leaves CLI continue active, pause/stop/evidence/finish passed.',
    )
  },
  { coreModule: 'session_core' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
