// PC-I07: source/cards/diagram, sparse zero bytes, residuals, camera and docking.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { openConnection, closeConnection } = require('./ui-commands.cjs')
const fs = require('node:fs'),
  path = require('node:path'),
  assert = require('node:assert/strict')
const { menuCommand } = require('./ui-commands.cjs')
const until = (predicate, timeout = 20000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'graphical',
  async ({ root, gui, launch }) => {
    const source = path.join(root, 'memory source.s')
    fs.writeFileSync(source, 'sw x0,0(x0)\nsb x0,7(x0)\nlw x1,0(x0)\nhalt\n')
    const steps = () =>
      fs
        .readFileSync(path.join(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    let { instance, page, errors } = await launch({
      viewport: { width: 1366, height: 768 },
      gpu: true,
    })
    const external = []
    page.on('request', (request) => {
      if (!/^(viewrv:|blob:|data:|http:\/\/127\.0\.0\.1:)/.test(request.url()))
        external.push(request.url())
    })
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await instance.evaluate(({ dialog }, source) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [source] })
    }, source)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir programa…')
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Más opciones de depuración', exact: true }).click()
    await page
      .getByRole('menuitem', { name: 'Depurar con diagrama interactivo', exact: true })
      .click()
    const diagram = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true }),
      inspector = diagram.getByRole('region', { name: 'Inspector del circuito', exact: true })
    const getFrame = async () => {
      const element = await page.locator('iframe[title="Diagrama de la sesión"]').elementHandle()
      return element.contentFrame()
    }
    let frame
    await until(async () => {
      frame = await getFrame()
      return frame && (await frame.evaluate(() => !!window.tp3SessionAdapter))
    })
    assert.equal(
      await page.getByRole('tab', { name: 'Estado del procesador', exact: true }).count(),
      0,
    )
    await menuCommand(page, 'Ver', 'Abrir vista de depuración')
    const resultsTab = page.getByRole('tab', { name: 'Estado del procesador', exact: true }),
      diagramTab = page.getByRole('tab', { name: 'Pipeline', exact: true }),
      results = page.getByRole('region', { name: 'Estado del procesador', exact: true })
    await results
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .waitFor()
    assert.equal(
      await resultsTab.evaluate((node) =>
        node
          .closest('[role=tablist]')
          .contains(
            [...document.querySelectorAll('[role=tab]')].find(
              (tab) => tab.textContent.trim() === 'Pipeline',
            ),
          ),
      ),
      true,
      'Results should open beside the existing diagram tab',
    )
    await diagramTab.click()
    assert.equal(steps(), 0, 'Opening and switching views advanced the processor')
    await frame.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph
      window.__originalGraph = graph
      window.__originalModel = graph.model
      window.__originalGeometry = JSON.stringify(
        Object.fromEntries(
          Object.entries(graph.model.cells)
            .filter(([, cell]) => cell.geometry)
            .map(([id, cell]) => [id, cell.geometry]),
        ),
      )
    })
    const value = (label) =>
      inspector.getByLabel('Formato de ' + label, { exact: true }).evaluate((node) => ({
        text: node.parentElement.querySelector('code').textContent,
        changed: node.parentElement.dataset.changed,
        title: node.parentElement.title,
      }))
    async function component(block) {
      await inspector.getByLabel('Componente del circuito', { exact: true }).selectOption(block)
      await until(
        async () =>
          (await inspector.getByLabel('Componente del circuito', { exact: true }).inputValue()) ===
          block,
      )
    }
    async function step(cycle) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await diagram.getByText(`Ciclo observado · ${cycle}`, { exact: true }).waitFor()
      assert.equal(steps(), cycle)
    }
    async function camera(graphFrame = frame) {
      return graphFrame.evaluate(() => {
        const g = window.tp3Viewer.viewer.graph
        return {
          scale: g.view.scale,
          x:
            (g.container.scrollLeft + g.container.clientWidth / 2) / g.view.scale -
            g.view.translate.x,
          y:
            (g.container.scrollTop + g.container.clientHeight / 2) / g.view.scale -
            g.view.translate.y,
        }
      })
    }
    function sameCamera(before, after) {
      assert.ok(Math.abs(before.scale - after.scale) < 0.00001)
      assert.ok(Math.abs(before.x - after.x) < 2 / before.scale, 'Camera centre x changed')
      assert.ok(Math.abs(before.y - after.y) < 2 / before.scale, 'Camera centre y changed')
    }
    const settledCamera = async () => {
      // Wait for resize and centering messages after the inspector changes height.
      await frame.evaluate(
        () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
      )
      return camera()
    }
    async function withTouch(verify) {
      const cdp = await page.context().newCDPSession(page)
      try {
        await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: true, maxTouchPoints: 2 })
        return await verify((type, touchPoints = []) =>
          cdp.send('Input.dispatchTouchEvent', { type, touchPoints }),
        )
      } finally {
        await cdp.send('Emulation.setTouchEmulationEnabled', { enabled: false })
        await cdp.detach()
      }
    }
    // Drag the second tab before the first, keeping both bound to the same session.
    const tabOrder = () =>
      diagramTab.evaluate((tab) =>
        [...tab.closest('[role=tablist]').querySelectorAll('[role=tab]')].map((node) =>
          node.getAttribute('aria-label'),
        ),
      )
    async function dragToTab(touch, origin, target) {
      const from = await origin.boundingBox(),
        to = await target.boundingBox()
      const x = from.x + 24,
        y = from.y + from.height / 2
      await touch('touchStart', [{ x, y }])
      await touch('touchMove', [{ x: to.x + 7, y: to.y + to.height / 2 }])
    }
    assert.deepEqual(await tabOrder(), ['Pipeline', 'Estado del procesador'])
    await withTouch(async (touch) => {
      await dragToTab(touch, resultsTab, diagramTab)
      await page.locator('.flexlayout__outline_rect').waitFor()
      await touch('touchCancel')
      assert.deepEqual(await tabOrder(), ['Pipeline', 'Estado del procesador'])
      await dragToTab(touch, resultsTab, diagramTab)
      await touch('touchEnd')
      await until(async () => (await tabOrder())[0] === 'Estado del procesador')
    })
    await diagramTab.click()
    await withTouch(async (touch) => {
      const target = await page.getByRole('tab', { name: /memory source.s/ }).evaluate((node) => {
        const box = document
          .getElementById(node.getAttribute('aria-controls'))
          .getBoundingClientRect()
        return { x: box.x + box.width / 2, y: box.y + box.height * 0.86 }
      })
      const origin = await diagramTab.boundingBox()
      const x = origin.x + 24,
        y = origin.y + origin.height / 2
      await touch('touchStart', [{ x, y }])
      await touch('touchMove', [{ x: x - 24, y }])
      await page.locator('.flexlayout__outline_rect').waitFor({ state: 'attached' })
      await touch('touchMove', [target])
      await touch('touchEnd')
      await until(async () => (await page.locator('.flexlayout__tabset').count()) === 3)
      await dragToTab(touch, diagramTab, resultsTab)
      await touch('touchEnd')
      await until(async () => (await tabOrder()).includes('Estado del procesador'))
    })
    assert.equal(
      await frame.evaluate(() => window.tp3Viewer.viewer.graph === window.__originalGraph),
      true,
    )
    await resultsTab.click()
    await withTouch(async (touch) => {
      const close = await resultsTab.getByTitle('Cerrar tab').boundingBox()
      await touch('touchStart', [{ x: close.x + close.width * 0.8, y: close.y + close.height / 2 }])
      await touch('touchEnd')
      await resultsTab.waitFor({ state: 'detached' })
    })
    await menuCommand(page, 'Ver', 'Abrir vista de depuración')
    await results
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .waitFor()
    await diagramTab.click()
    await frame.locator('#zoom-in').click()
    const beforeZoomOut = await camera()
    await frame.locator('#zoom-out').click()
    await until(async () => (await camera()).scale < beforeZoomOut.scale)
    await frame.locator('#zoom-in').click()
    await frame.locator('#zoom-in').click()
    const beforeFit = await camera()
    await frame.locator('#fit').click()
    await until(async () => (await camera()).scale !== beforeFit.scale)
    await step(1)
    await page.getByRole('tab', { name: /memory source.s/ }).click()
    const editor = page.locator('.monaco-editor:visible [role="textbox"]').first()
    await editor.focus()
    await page.keyboard.press('Control+Home')
    await page.keyboard.press('Control+Alt+F9')
    await page
      .getByRole('dialog', { name: 'Apariciones de la línea 1', exact: true })
      .getByRole('button', { name: 'Seleccionar IF/ID', exact: true })
      .click()
    await until(
      async () =>
        (await inspector.getByLabel('Componente del circuito', { exact: true }).inputValue()) ===
        'latch.if_id',
    )
    assert.equal(steps(), 1)
    await frame.locator('#zoom-in').click()
    await frame.locator('#zoom-in').click()
    const beforeHide = await settledCamera()
    await page.getByRole('tab', { name: 'Estado del procesador', exact: true }).click()
    await page.getByRole('region', { name: 'Estado del procesador', exact: true }).waitFor()
    await page.getByRole('tab', { name: 'Pipeline', exact: true }).click()
    await diagram.waitFor()
    sameCamera(beforeHide, await camera())
    await step(2)
    await page.getByRole('tab', { name: 'Estado del procesador', exact: true }).click()
    const state = page.getByRole('region', { name: 'Estado del procesador', exact: true })
    await state
      .getByRole('region', { name: 'Registro ID/EX', exact: true })
      .getByRole('heading', { name: 'ID/EX Instrucción válida', exact: true })
      .waitFor()
    await page.getByRole('tab', { name: 'Pipeline', exact: true }).click()
    await component('latch.id_ex')
    assert.equal(steps(), 2)
    await step(3)
    await editor.focus()
    await page.keyboard.press('Control+Home')
    await page.keyboard.press('Control+Alt+F9')
    await page
      .getByRole('dialog', { name: 'Apariciones de la línea 1', exact: true })
      .getByRole('button', { name: 'Seleccionar EX/MEM', exact: true })
      .click()
    await until(
      async () =>
        (await inspector.getByLabel('Componente del circuito', { exact: true }).inputValue()) ===
        'latch.ex_mem',
    )
    await page.waitForFunction(() => {
      const editor = document.querySelector('.monaco-editor'),
        line = [...editor.querySelectorAll('.view-line')].find((node) =>
          node.textContent.replaceAll('\u00a0', ' ').includes('sw x0'),
        ),
        selected = editor.querySelector('.viewrv-selected-occurrence-line')
      return (
        !!line &&
        !!selected &&
        Math.abs(line.getBoundingClientRect().top - selected.getBoundingClientRect().top) < 2
      )
    })
    await step(4)
    await component('mem.data_memory')
    assert.equal((await value('used_count')).text, '0x0000000004')
    for (const address of [0, 1, 2, 3]) {
      const cell = await value(`mem[0x${address}]`)
      assert.equal(cell.text, '0x00')
      assert.equal(cell.changed, 'true')
      assert.match(cell.title, /byte no observado antes/)
    }
    assert.equal(await inspector.getByLabel('Formato de mem[0x4]', { exact: true }).count(), 0)
    await inspector.getByLabel('Formato de mem[0x0]', { exact: true }).selectOption('unsigned')
    assert.equal(
      await inspector.getByLabel('Formato de mem[0x1]', { exact: true }).inputValue(),
      'hex',
    )
    await step(5)
    assert.equal((await value('used_count')).text, '0x0000000005')
    assert.equal((await value('mem[0x7]')).text, '0x00')
    assert.equal((await value('mem[0x7]')).changed, 'true')
    assert.equal((await value('mem[0x0]')).changed, 'false')
    assert.equal(
      await inspector.getByLabel('Formato de mem[0x0]', { exact: true }).inputValue(),
      'unsigned',
    )
    for (const address of [4, 5, 6])
      assert.equal(
        await inspector.getByLabel(`Formato de mem[0x${address}]`, { exact: true }).count(),
        0,
      )
    await page.screenshot({ path: path.resolve(gui, '../build/gui-pc-i07-sparse-zero.png') })
    await component('rf.register_file')
    for (let register = 0; register < 32; register++)
      assert.equal((await value('x' + register)).text, '0x00000000')
    await component('session.execution_control')
    assert.equal((await value('cycle_count')).text, '5')
    assert.equal((await value('global_state')).text, 'STEPPING (0x05)')
    await component('if.pc')
    assert.equal((await value('pc')).text, '0x00000014')
    await component('latch.if_id')
    assert.equal((await value('if_id.valid')).text, '0x0')
    assert.equal((await value('if_id.pc')).text, '0x00000010')
    assert.equal((await value('if_id.fetch_fault_valid')).text, '0x1')
    assert.equal((await value('if_id.fetch_fault_cause')).text, '0x1')
    await diagram
      .getByText('Fetch pendiente de confirmación · PC 0x00000010 · INSTRUCTION_ACCESS_FAULT', {
        exact: true,
      })
      .waitFor()
    assert.equal(
      await inspector
        .getByRole('button', { name: 'Seguir esta instrucción', exact: true })
        .isDisabled(),
      true,
    )
    await component('latch.ex_mem')
    await inspector.getByRole('button', { name: 'Seguir esta instrucción', exact: true }).click()
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    assert.equal(steps(), 5)
    await step(6)
    await diagram.getByText('HALT recibido: drenando el pipeline.', { exact: true }).waitFor()
    assert.equal(await diagram.getByRole('img', { name: 'Candidato de fallo de fetch' }).count(), 0)
    await until(
      async () =>
        (await inspector.getByLabel('Componente del circuito', { exact: true }).inputValue()) ===
        'latch.mem_wb',
    )
    const beforeRetire = await settledCamera()
    await step(7)
    await diagram.getByText('Ejecución finalizada', { exact: true }).waitFor()
    assert.equal(await diagram.getByRole('alert').count(), 0)
    await inspector.getByText('La aparición terminó su recorrido.', { exact: true }).waitFor()
    sameCamera(beforeRetire, await settledCamera())
    assert.equal((await value('mem_wb.valid')).text, '0x0')
    assert.equal((await value('mem_wb.instruction')).text, '0x00002083')
    assert.equal((await value('mem_wb.reg_write')).text, '0x1')
    assert.equal(await page.locator('.viewrv-selected-occurrence-line:visible').count(), 0)
    await page.screenshot({ path: path.resolve(gui, '../build/gui-pc-i07-residuals.png') })
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    await page.getByLabel('Escala de la interfaz', { exact: true }).selectOption('1.25')
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await page.setViewportSize({ width: 1366, height: 768 })
    await until(() =>
      instance.evaluate(
        ({ BrowserWindow }) =>
          BrowserWindow.getAllWindows()[0].webContents.getZoomFactor() === 1.25,
      ),
    )
    await inspector
      .getByLabel('Componente del circuito', { exact: true })
      .selectOption('latch.if_id')
    await inspector.getByRole('button', { name: 'Centrar componente', exact: true }).click()
    const visible = await inspector
      .getByLabel('Componente del circuito', { exact: true })
      .evaluate((node) => {
        const box = node.getBoundingClientRect(),
          hit = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2)
        return hit === node
      })
    assert.equal(visible, true, 'The inspector controls were clipped in notebook split at 125%')
    await page.screenshot({
      path: path.resolve(gui, '../build/gui-pc-i07-notebook-docked-125.png'),
    })
    assert.equal(
      await frame.evaluate(() => {
        const g = window.tp3Viewer.viewer.graph
        return (
          g === window.__originalGraph &&
          g.model === window.__originalModel &&
          JSON.stringify(
            Object.fromEntries(
              Object.entries(g.model.cells)
                .filter(([, cell]) => cell.geometry)
                .map(([id, cell]) => [id, cell.geometry]),
            ),
          ) === window.__originalGeometry
        )
      }),
      true,
    )
    assert.equal(steps(), 7)
    await page.getByRole('button', { name: 'Ajustes', exact: true }).click()
    await page.getByLabel('Escala de la interfaz', { exact: true }).selectOption('1')
    await until(() =>
      instance.evaluate(
        ({ BrowserWindow }) => BrowserWindow.getAllWindows()[0].webContents.getZoomFactor() === 1,
      ),
    )
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    // Restart from the results tab: both already open views must bind to the new debug session.
    await resultsTab.click()
    await results.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Reiniciar depuración', exact: true }).click()
    await results
      .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
      .waitFor()
    await diagramTab.click()
    await diagram.getByText('Sin captura recibida', { exact: true }).waitFor()
    await page
      .frameLocator('iframe[title="Diagrama de la sesión"]')
      .locator('#zoom-in:enabled')
      .waitFor()
    assert.equal(steps(), 7, 'Reopening the new session issued STEP')
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await diagram.getByText('Ciclo observado · 1', { exact: true }).waitFor()
    await resultsTab.click()
    await results.getByRole('group', { name: 'Ciclo observado: 1', exact: true }).waitFor()
    assert.equal(steps(), 8)
    assert.equal(steps(), 8)
    assert.deepEqual(errors, [])
    assert.deepEqual(external, [])
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    console.log(
      'PC-I07 graphical: touch tabs reorder, dock, cancel and close. Shared captures, restart, source correlation, zoom buttons and stable graph geometry passed with literal UART captures.',
    )
  },
  { coreModule: 'educational_core', trace: 'memory' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
