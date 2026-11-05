// TEST-PC-003/005/011/017/026/029: real Electron interaction; hardware replies are controlled.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { openConnection, closeConnection } = require('./ui-commands.cjs')
const { existsSync, readFileSync, writeFileSync, unlinkSync } = require('node:fs')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const until = (predicate, timeout = 18000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'ide',
  async ({ root, gui, launch }) => {
    const discovery = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    const source = resolve(root, 'exact source.s')
    writeFileSync(source, 'addi x1,x0,5\nhalt\n')
    let { instance, page, errors } = await launch({
      viewport: { width: 1366, height: 768 },
      gpu: false,
    })
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page.getByText('Tu espacio para programar', { exact: true }).waitFor()
    await page.getByRole('button', { name: /Crear programa/ }).hover()
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-welcome.png') })
    async function menu(group, item) {
      await page.getByRole('button', { name: group, exact: true }).click()
      await page.getByRole('menuitem', { name: item, exact: true }).click()
    }
    await instance.evaluate(({ dialog }, source) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [source] })
    }, source)
    await menu('Archivo', 'Abrir programa…')
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).waitFor()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    assert.equal(await page.getByRole('button', { name: 'Cargar', exact: true }).isDisabled(), true)
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await page.getByText('Programa ensamblado', { exact: true }).waitFor()
    await page.getByRole('button', { name: 'Ver ensamblado', exact: true }).click()
    await page.getByRole('heading', { name: 'Vista ensamblada', exact: true }).waitFor()
    assert.equal(
      await page.getByRole('button', { name: 'Cargar', exact: true }).isDisabled(),
      true,
      'Documentation focus silently chose source',
    )
    await page.getByText('exact source.s', { exact: true }).first().click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await page.getByText('Programa cargado en la FPGA', { exact: true }).waitFor()
    const steps = () =>
      readFileSync(resolve(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    const before = steps()
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await page.getByRole('heading', { name: 'Listo para el primer ciclo', exact: true }).waitFor()
    assert.equal(steps(), before, 'Starting debugger issued STEP')
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await page
      .getByRole('region', { name: 'Registro IF/ID', exact: true })
      .getByRole('img', { name: 'Instrucción válida', exact: true })
      .waitFor()
    await until(() =>
      page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
    )
    assert.equal(steps(), before + 1)
    const processor = page.getByRole('region', { name: 'Estado del procesador', exact: true })
    await processor.getByRole('group', { name: 'Ciclo observado: 1', exact: true }).waitFor()
    assert.equal(
      await processor.locator(':scope > header').getByText('Pausado', { exact: true }).count(),
      0,
    )
    while (await page.getByRole('button', { name: 'Cerrar notificación', exact: true }).count())
      await page.getByRole('button', { name: 'Cerrar notificación', exact: true }).first().click()
    assert.ok(
      (await page.locator('.viewrv-breakpoint-slot').count()) >= 2,
      'Active debug needs discoverable breakpoint targets',
    )
    await page.locator('.viewrv-breakpoint-slot').first().hover()
    await page.locator('.viewrv-breakpoint-hover').waitFor()
    await page
      .getByRole('button', { name: 'Elegir registro del breakpoint de la línea 1', exact: true })
      .focus()
    await page.keyboard.press('Enter')
    await page.getByRole('dialog', { name: 'Breakpoint de la línea 1' }).waitFor()
    const picker = page.getByRole('dialog', { name: 'Breakpoint de la línea 1', exact: true })
    const arrow = page.getByRole('button', {
      name: 'Elegir registro del breakpoint de la línea 1',
      exact: true,
    })
    async function anchoredBelow() {
      const a = await arrow.boundingBox(),
        p = await picker.boundingBox()
      return (
        a &&
        p &&
        p.y >= a.y + a.height &&
        p.y < a.y + a.height + 48 &&
        p.x < a.x + a.width &&
        p.x + p.width > a.x
      )
    }
    await until(anchoredBelow)
    await page.setViewportSize({ width: 1100, height: 768 })
    await until(anchoredBelow)
    await page.setViewportSize({ width: 1366, height: 768 })
    await until(anchoredBelow)
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-breakpoint.png') })
    await page.getByRole('button', { name: 'IF/ID · entrada a ID', exact: true }).click()
    await page.getByRole('button', { name: 'Continuar', exact: true }).click()
    await page
      .getByRole('status', { name: 'Breakpoint alcanzado', exact: true })
      .getByRole('listitem', { name: 'Línea 1 en IF/ID', exact: true })
      .waitFor()
    assert.equal(steps(), before + 2)
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-debug.png') })
    await page.screenshot({
      path: resolve(gui, '../build/gui-pc-i06-corners.png'),
      clip: { x: 54, y: 82, width: 1310, height: 80 },
    })
    await page.getByLabel('Formato de IF/ID.pc', { exact: true }).selectOption('unsigned')
    assert.equal(
      await page.getByLabel('Formato de pc', { exact: true }).inputValue(),
      'hex',
      'Format selection changed another value',
    )
    const beforeZoom = steps()
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    await page.getByLabel('Escala de la interfaz', { exact: true }).selectOption('1.25')
    await until(() =>
      instance.evaluate(
        ({ BrowserWindow }) =>
          BrowserWindow.getAllWindows()[0].webContents.getZoomFactor() === 1.25,
      ),
    )
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).waitFor()
    assert.equal(
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).evaluate((node) => {
        const r = node.getBoundingClientRect()
        return (
          r.left >= 0 &&
          r.right <= window.innerWidth &&
          r.top >= 0 &&
          r.bottom <= window.innerHeight
        )
      }),
      true,
      'Zoom hid processor controls',
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-debug-125.png') })
    assert.equal(steps(), beforeZoom, 'Zoom or navigation advanced CPU')
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    await page.getByLabel('Escala de la interfaz', { exact: true }).selectOption('1')
    await until(() =>
      instance.evaluate(
        ({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].webContents.getZoomFactor() === 1,
      ),
    )
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menu('Ver', 'Dividir arriba/abajo')
    await menu('Archivo', 'Crear programa')
    const input = page.locator('.monaco-editor [role="textbox"]').last()
    await input.waitFor({ state: 'attached' })
    await input.focus()
    await page.evaluate(() => {
      window.__pc06Latency = []
      const onKey = (event) => {
        if (event.key.length === 1) {
          const started = event.timeStamp
          requestAnimationFrame(() =>
            requestAnimationFrame(() => window.__pc06Latency.push(performance.now() - started)),
          )
        }
      }
      document.addEventListener('keydown', onKey, true)
      window.__pc06StopLatency = () => document.removeEventListener('keydown', onKey, true)
    })
    await page.keyboard.type('# another program while debugging')
    await until(() => page.evaluate(() => window.__pc06Latency.length >= 33))
    const samples = await page.evaluate(() => {
      window.__pc06StopLatency()
      return window.__pc06Latency
    })
    writeFileSync(
      resolve(gui, '../build/gui-pc-i06-latency.json'),
      JSON.stringify(
        {
          method:
            'keydown to second requestAnimationFrame; conservative visible-response upper bound on the available Arch host, controlled UART',
          samples_ms: samples,
          max_ms: Math.max(...samples),
        },
        null,
        2,
      ) + '\n',
    )
    assert.ok(
      samples.every((value) => value < 100),
      'Visible response exceeded 100 ms; inspect all latency samples',
    )
    assert.equal(
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      true,
    )
    await page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).click()
    await page
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .first()
      .waitFor()
    assert.equal(steps(), before + 2, 'Restart issued initial STEP')
    await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isVisible())
    await page.getByRole('tab', { name: 'exact source.s', exact: true }).first().click()
    assert.equal(
      await page.getByRole('button', { name: 'Correr', exact: true }).isDisabled(),
      true,
      'Stopped debug silently became a fresh image',
    )
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Correr', exact: true }).isEnabled())
    writeFileSync(resolve(root, 'run.wait'), 'wait')
    await page.getByRole('button', { name: 'Correr', exact: true }).click()
    await page.getByRole('button', { name: 'Detener ejecución (RESET)', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Detener ejecución (RESET)', exact: true }).click()
    await page.getByText('Sin programa cargado', { exact: true }).waitFor()
    await until(() => page.getByRole('button', { name: 'Correr', exact: true }).isVisible())
    assert.equal(await page.getByRole('button', { name: 'Correr', exact: true }).isDisabled(), true)
    unlinkSync(resolve(root, 'run.wait'))
    await page.getByText('exact source.s', { exact: true }).first().click()
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Correr', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Correr', exact: true }).click()
    await page.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).first().waitFor()
    await page.setViewportSize({ width: 1920, height: 1080 })
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-result.png') })
    await page.getByRole('tab', { name: 'exact source.s', exact: true }).first().click()
    const runRequests = [],
      loadRequests = [],
      sourceUpdates = []
    page.on('request', (req) => {
      if (req.url().endsWith('/run/start')) runRequests.push(JSON.parse(req.postData()))
      if (req.url().endsWith('/program/load')) loadRequests.push(JSON.parse(req.postData()))
      if (req.url().endsWith('/program/update')) sourceUpdates.push(JSON.parse(req.postData()))
    })
    const sourceInput = page.locator('.monaco-editor [role="textbox"]').first(),
      largeSource = 'addi x1,x0,5\n' + 'addi x0,x0,0\n'.repeat(600) + 'halt\n',
      afterEnterFormat = largeSource.replace(/halt\n$/, '    halt\n    ')
    await sourceInput.focus()
    await page.keyboard.press('Control+a')
    await page.keyboard.insertText(largeSource)
    await until(() => sourceUpdates.some((update) => update.source_text === afterEnterFormat))
    writeFileSync(resolve(root, 'load.wait'), 'wait')
    if (existsSync(resolve(root, 'load.payload'))) unlinkSync(resolve(root, 'load.payload'))
    await page.getByRole('button', { name: 'Más opciones de ejecución', exact: true }).click()
    assert.equal(
      await page
        .getByRole('menuitem', { name: 'Ensamblar, cargar y correr', exact: true })
        .isEnabled(),
      true,
    )
    await page.keyboard.press('Escape')
    await sourceInput.focus()
    await page.keyboard.press('Control+Shift+Enter')
    await until(() => existsSync(resolve(root, 'load.payload')))
    await sourceInput.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# edited after LOAD admission')
    unlinkSync(resolve(root, 'load.wait'))
    await until(() => runRequests.length === 1)
    await page.getByRole('tab', { name: 'exact source.s ●', exact: true }).first().waitFor()
    await page.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).first().waitFor()
    assert.deepEqual(Object.keys(runRequests[0]).sort(), ['program_id', 'source_version'])
    assert.equal(runRequests[0].source_version, loadRequests[0].source_version)
    assert.equal(runRequests[0].program_id, loadRequests[0].program_id)
    assert.equal(
      loadRequests[0].source_text,
      afterEnterFormat,
      'Combined shortcut unexpectedly edited the document',
    )
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    assert.equal(
      await page.locator('.flexlayout__tab_button:visible').count(),
      0,
      'Hidden IDE tab controls leaked into settings',
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-settings.png') })
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page.getByRole('tab', { name: 'exact source.s ●', exact: true }).first().click()
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await page
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .first()
      .waitFor()
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await until(() =>
      page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
    )
    const lastComplete = steps()
    writeFileSync(resolve(root, 'step.drop'), 'drop')
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await page.getByText('Se perdió la comunicación con la FPGA', { exact: true }).first().waitFor()
    await page.getByText('Último estado recibido · ciclo 1', { exact: true }).first().waitFor()
    await page
      .getByText(
        'Comunicación recuperada. Volvé a cargar el programa para iniciar una nueva depuración.',
        { exact: true },
      )
      .first()
      .waitFor({ timeout: 20000 })
    assert.equal(steps(), lastComplete + 1, 'Recovery replayed STEP')
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-recovery.png') })
    unlinkSync(resolve(root, 'step.drop'))
    await page.getByText('exact source.s', { exact: true }).first().click()
    assert.equal(
      await page.getByRole('button', { name: 'Empezar debug', exact: true }).isDisabled(),
      true,
    )
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await page
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .first()
      .waitFor()
    await page.getByRole('button', { name: 'Continuar', exact: true }).click()
    const navigating = steps()
    await page.getByRole('button', { name: 'Visor interactivo', exact: true }).click()
    await until(() => steps() > navigating + 2)
    writeFileSync(resolve(root, 'step.fault'), 'fault')
    await until(async () => {
      const response = await fetch(discovery.base_url + '/api/v1/session/list', {
        headers: { Authorization: 'Bearer ' + discovery.access_token },
      })
      const data = await response.json()
      return data.result.sessions.some((item) => item.execution_status === 'fault')
    })
    assert.equal(
      await page.getByRole('button', { name: 'IDE', exact: true }).getAttribute('aria-pressed'),
      'false',
      'Terminal result changed sections',
    )
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page
      .getByRole('heading', { name: 'Procesador detenido por fault', exact: true })
      .first()
      .waitFor()
    assert.equal(
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isDisabled(),
      true,
    )
    assert.equal(
      await page.getByRole('button', { name: 'Continuar', exact: true }).isDisabled(),
      true,
    )
    assert.equal(
      await page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).isEnabled(),
      true,
    )
    const beforeViewClose = steps()
    await menu('Archivo', 'Cerrar tab')
    assert.equal(
      await page.getByRole('button', { name: 'Detener depuración', exact: true }).isEnabled(),
      true,
    )
    await menu('Ver', 'Abrir vista de depuración')
    await page
      .getByRole('heading', { name: 'Procesador detenido por fault', exact: true })
      .first()
      .waitFor()
    assert.equal(steps(), beforeViewClose, 'Closing/reopening debugger advanced or restarted CPU')
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i06-fault.png') })
    assert.deepEqual(errors, [])
    const close = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await close
    await instance.close()
    instance = null
    console.log(
      'PC-I06 GUI: menus, welcome hover, real assembly/view, exact LOAD, initial debug without STEP, one-step capture, breakpoint selector/hit, independent formats, split, editing another program, restart without STEP, RUN/RESET, automatic terminal results, combined sequence with editing during LOAD, settings and close passed.',
    )
  },
  { coreModule: 'session_core' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
