const { openConnection, closeConnection } = require('./ui-commands.cjs')
// PC-I07: source/cards/diagram, sparse zero bytes, residuals, camera and docking.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const fs = require('node:fs'),
  path = require('node:path'),
  os = require('node:os'),
  assert = require('node:assert/strict')
const { menuCommand } = require('./ui-commands.cjs')
const gui = path.resolve(__dirname, '..'),
  tp3 = path.resolve(gui, '../..'),
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-graphical-'))
const env = {
  ...process.env,
  PYTHONPATH: tp3,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: path.join(root, 'state'),
  XDG_DATA_HOME: path.join(root, 'data'),
  XDG_CONFIG_HOME: path.join(root, 'config'),
  VIEWRV_TEST_CONTROL: root,
  VIEWRV_EDUCATIONAL_TRACE: 'memory',
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate, timeout = 20000) {
  const end = Date.now() + timeout
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await wait(25)
  }
  throw Error('Condition timed out')
}
;(async () => {
  const core = spawn(
    path.resolve(gui, '../.venv/bin/python'),
    ['-m', 'software.tests.viewrv.educational_core'],
    { cwd: tp3, env, stdio: ['ignore', 'ignore', 'pipe'] },
  )
  let instance, page
  try {
    await until(() => fs.existsSync(path.join(root, 'viewrv/core.json')))
    const source = path.join(root, 'memory source.s')
    fs.writeFileSync(source, 'sw x0,0(x0)\nsb x0,7(x0)\nlw x1,0(x0)\nhalt\n')
    const steps = () =>
      fs
        .readFileSync(path.join(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    instance = await electron.launch({
      executablePath: path.resolve(gui, 'node_modules/electron/dist/electron'),
      args: [gui, '--ozone-platform=x11', `--user-data-dir=${path.join(root, 'profile')}`],
      env,
    })
    page = await instance.firstWindow()
    await page.setViewportSize({ width: 1366, height: 768 })
    const errors = [],
      external = []
    page.on('pageerror', (error) => errors.push(String(error)))
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
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
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
    async function camera() {
      return frame.evaluate(() => {
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
    const beforeHide = await camera()
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
    const correlation = await page.evaluate(() => {
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
    assert.equal(correlation, true, 'Selected diagram latch did not identify its exact source line')
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
    assert.equal((await value('cycle_count')).text, '0x0000000000000005')
    assert.equal((await value('global_state')).text, '0x05')
    await component('if.pc')
    assert.equal((await value('pc')).text, '0x00000014')
    await component('latch.if_id')
    assert.equal((await value('if_id.valid')).text, '0x0')
    assert.equal((await value('if_id.pc')).text, '0x00000010')
    assert.equal((await value('if_id.fetch_fault_valid')).text, '0x1')
    await inspector
      .getByText(
        'Hay un candidato de fetch independiente de valid. Se conserva su causa recibida.',
        { exact: true },
      )
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
    await until(
      async () =>
        (await inspector.getByLabel('Componente del circuito', { exact: true }).inputValue()) ===
        'latch.mem_wb',
    )
    const beforeRetire = await camera()
    await step(7)
    await inspector.getByText('La aparición terminó su recorrido.', { exact: true }).waitFor()
    sameCamera(beforeRetire, await camera())
    assert.equal((await value('mem_wb.valid')).text, '0x0')
    assert.equal((await value('mem_wb.instruction')).text, '0x00002083')
    assert.equal((await value('mem_wb.reg_write')).text, '0x1')
    assert.equal(await page.locator('.viewrv-selected-occurrence-line:visible').count(), 0)
    await page.screenshot({ path: path.resolve(gui, '../build/gui-pc-i07-residuals.png') })
    await page.setViewportSize({ width: 1920, height: 1080 })
    // FlexLayout settles its ResizeObserver layout before measuring drag targets.
    await page.evaluate(
      () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
    )
    const tab = page.getByRole('tab', { name: 'Pipeline', exact: true }),
      target = await page.getByRole('tab', { name: /memory source.s/ }).evaluate((node) => {
        const box = document
          .getElementById(node.getAttribute('aria-controls'))
          .getBoundingClientRect()
        return { x: box.x, y: box.y, width: box.width, height: box.height }
      }),
      origin = await tab.boundingBox()
    await page.mouse.move(origin.x + origin.width / 2, origin.y + origin.height / 2)
    await page.mouse.down()
    await page.mouse.move(origin.x + origin.width / 2, origin.y + origin.height / 2 + 12, {
      steps: 3,
    })
    await page.mouse.move(target.x + target.width / 2, target.y + target.height - 8, { steps: 15 })
    await page.mouse.up()
    await until(async () => (await page.locator('.flexlayout__tabset').count()) >= 3)
    assert.equal(
      await frame.evaluate(
        () =>
          window.tp3Viewer.viewer.graph === window.__originalGraph &&
          window.tp3Viewer.viewer.graph.model === window.__originalModel,
      ),
      true,
      'Docking reconstructed the same graph view',
    )
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
    assert.deepEqual(errors, [])
    assert.deepEqual(external, [])
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    await until(() => !fs.existsSync(path.join(root, 'viewrv/core.json')))
    console.log(
      'PC-I07 graphical: bidirectional occurrence selection, exact source correlation, sparse/new zero bytes, independent formats, RF32/global/fetch candidate/residual fields, follow retirement camera, hidden-tab camera, docking, notebook 125%, stable model/geometry and no extra STEP passed. UART is a literal test-only memory trace.',
    )
  } catch (error) {
    if (page && !page.isClosed())
      await page
        .screenshot({ path: path.resolve(gui, '../build/gui-pc-i07-graphical-failure.png') })
        .catch(() => {})
    throw error
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
    fs.rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
