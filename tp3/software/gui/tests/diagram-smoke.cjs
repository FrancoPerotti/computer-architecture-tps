const { openConnection, closeConnection } = require('./ui-commands.cjs')
// PC-I07: real GraphViewer + Electron/core, with a fixed test-only UART trace.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand } = require('./ui-commands.cjs')
const gui = resolve(__dirname, '..'),
  tp3 = resolve(gui, '../..'),
  root = mkdtempSync(resolve(tmpdir(), 'viewrv-pc07-graph-'))
const env = {
  ...process.env,
  PYTHONPATH: tp3,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_DATA_HOME: resolve(root, 'data'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  VIEWRV_TEST_CONTROL: root,
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate, timeout = 20000) {
  const end = Date.now() + timeout
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await wait(30)
  }
  throw Error('Condition timed out')
}
;(async () => {
  const core = spawn(
    resolve(gui, '../.venv/bin/python'),
    ['-m', 'software.tests.viewrv.educational_core'],
    { cwd: tp3, env, stdio: ['ignore', 'ignore', 'pipe'] },
  )
  let instance, page
  try {
    await until(() => existsSync(resolve(root, 'viewrv/core.json')))
    const source = resolve(root, 'seven captures.s')
    writeFileSync(source, 'addi x1,x0,5\naddi x2,x0,2\nadd x2,x1,x1\nhalt\n')
    const steps = () =>
      readFileSync(resolve(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
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
    page = await instance.firstWindow()
    await page.setViewportSize({ width: 1600, height: 1000 })
    const errors = [],
      external = []
    page.on('pageerror', (error) => errors.push(String(error)))
    page.on('request', (request) => {
      if (!/^(viewrv:|blob:|data:|http:\/\/127\.0\.0\.1:)/.test(request.url()))
        external.push(request.url())
    })
    await openConnection(page)
    await page
      .getByRole('button', { name: 'Preparar Basys 3', exact: true })
      .waitFor({ timeout: 25000 })
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
    await page.getByRole('heading', { name: 'Listo para el primer ciclo', exact: true }).waitFor()
    assert.equal(steps(), 0)
    await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
    const region = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true })
    await region.waitFor()
    async function frame() {
      const node = await page.locator('iframe[title="Diagrama de la sesión"]').elementHandle()
      return node.contentFrame()
    }
    let graphFrame
    await until(async () => {
      graphFrame = await frame()
      return graphFrame && (await graphFrame.evaluate(() => !!window.tp3SessionAdapter))
    })
    await until(() =>
      region
        .getByText('Sin captura completa. Los valores no se presumen cero.', { exact: true })
        .isVisible(),
    )
    assert.equal(steps(), 0, 'Opening diagram issued STEP')
    await graphFrame.evaluate(() => {
      window.__originalGraph = window.tp3Viewer.viewer.graph
      window.__originalModel = window.__originalGraph.model
      window.__originalGeometry = JSON.stringify(
        Object.fromEntries(
          Object.entries(window.__originalModel.cells)
            .filter(([, cell]) => !!cell.geometry)
            .map(([id, cell]) => [
              id,
              {
                x: cell.geometry.x,
                y: cell.geometry.y,
                width: cell.geometry.width,
                height: cell.geometry.height,
              },
            ]),
        ),
      )
    })
    // Drive a rendered native module; the observer verifies the frame bridge.
    const bindings = JSON.parse(
      readFileSync(resolve(gui, '../resources/content/diagram_bindings.json'), 'utf8'),
    )
    await page.evaluate(() => {
      window.__pc07GraphSelections = []
      window.addEventListener('message', (event) => {
        if (event.data?.channel === 'viewrv-graph-v1' && event.data.kind === 'select')
          window.__pc07GraphSelections.push(event.data.block_id)
      })
    })
    await region
      .getByLabel('Componente del circuito', { exact: true })
      .selectOption('rf.register_file')
    await region.getByRole('button', { name: 'Centrar componente', exact: true }).click()
    async function clickNativeCell(id) {
      const point = await graphFrame.evaluate((id) => {
        const graph = window.tp3Viewer.viewer.graph,
          render = graph.view.getState(graph.model.getCell(id))
        const box = render?.shape?.node?.getBoundingClientRect()
        if (!box || !box.width || !box.height) throw Error('Native cell is not rendered: ' + id)
        return { x: box.x + box.width / 2, y: box.y + box.height / 2 }
      }, id)
      const bounds = await page.locator('iframe[title="Diagrama de la sesión"]').boundingBox()
      await page.mouse.click(bounds.x + point.x, bounds.y + point.y)
    }
    // Clear only the native selection without moving its camera, so the RF stays visible.
    await graphFrame.evaluate(() => window.tp3SessionAdapter.selectComponent('if.pc'))
    await clickNativeCell(bindings.blocks['rf.register_file'])
    await until(() =>
      page.evaluate(() => window.__pc07GraphSelections.includes('rf.register_file')),
    )
    assert.equal(steps(), 0, 'A native graph click issued STEP')
    const wirePoint = await graphFrame.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph,
        render = graph.view.getState(graph.model.getCell('d6Z_Gf_YBklqbeCfQCJ9-114'))
      const paths = Array.from(render.shape.node.querySelectorAll('path[d]'))
      const path = paths.find((path) => path.getTotalLength() > 0),
        point = path.getPointAtLength(path.getTotalLength() / 2)
      const screen = new DOMPoint(point.x, point.y).matrixTransform(path.getScreenCTM())
      return { x: screen.x, y: screen.y }
    })
    const graphBounds = await page.locator('iframe[title="Diagrama de la sesión"]').boundingBox()
    await page.mouse.click(graphBounds.x + wirePoint.x, graphBounds.y + wirePoint.y)
    await region
      .getByText(
        'Explicación conceptual de la conexión. UART no transmite su valor; no se reconstruyen señales adicionales.',
        { exact: true },
      )
      .waitFor()
    assert.equal(
      await region.getByLabel('Componente del circuito', { exact: true }).inputValue(),
      '',
    )
    assert.equal(steps(), 0, 'A native connection click issued STEP')
    await region.getByLabel('Componente del circuito', { exact: true }).selectOption('if.pc')

    const panelStyles = await page.locator('.flexlayout__tab:visible').evaluateAll((nodes) =>
      nodes.map((node) => ({
        radius: getComputedStyle(node).borderBottomLeftRadius,
        clip: getComputedStyle(node).clipPath,
      })),
    )
    assert.ok(
      panelStyles.length > 0 &&
        panelStyles.every((value) => value.radius === '12px' && value.clip.includes('12px')),
      'Panel content lost its rounded clipping',
    )
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-no-capture.png') })
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await region.getByText('Ciclo observado · 1', { exact: true }).waitFor()
    await until(() =>
      graphFrame.evaluate(() => {
        const g = window.tp3Viewer.viewer.graph
        return g.getCellStyle(g.model.getCell('PeWG_VKsY-f66Zm0Bl_l-193')).strokeColor === '#b80078'
      }),
    )
    await region.getByLabel('Componente del circuito', { exact: true }).selectOption('latch.if_id')
    await until(() =>
      region.getByRole('button', { name: 'Seguir esta instrucción', exact: true }).isEnabled(),
    )
    await region.getByRole('button', { name: 'Seguir esta instrucción', exact: true }).click()
    await region.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    assert.equal(steps(), 1, 'Selection/follow issued an extra STEP')
    for (const [cycle, component] of [
      [2, 'latch.id_ex'],
      [3, 'latch.ex_mem'],
      [4, 'latch.mem_wb'],
    ]) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await region.getByText(`Ciclo observado · ${cycle}`, { exact: true }).waitFor()
      await until(
        async () =>
          (await region.getByLabel('Componente del circuito', { exact: true }).inputValue()) ===
          component,
      )
      assert.equal(steps(), cycle)
      assert.ok(
        (await page.locator('.viewrv-selected-occurrence-line:visible').count()) > 0,
        'Source correlation is absent',
      )
    }
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-follow.png') })
    const labelFrames = await graphFrame.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph
      const labels = Object.values(graph.model.cells).filter((cell) => {
        return (
          !graph.model.isEdge(cell) &&
          (/(?:^|;)text(?:;|$)/.test(cell.style) ||
            /(?:^|;)strokeColor=none(?:;|$)/.test(cell.style))
        )
      })
      return {
        count: labels.length,
        framed: labels
          .filter((cell) => {
            const style = graph.getCellStyle(cell)
            return ['#b80078', '#4338ca'].includes(style.strokeColor)
          })
          .map((cell) => cell.id),
      }
    })
    assert.ok(labelFrames.count > 20, 'Expected native labels to be covered')
    assert.deepEqual(labelFrames.framed, [], 'Activity/selection added colored borders to labels')
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await region.getByText('La aparición terminó su recorrido.', { exact: true }).waitFor()
    assert.equal(steps(), 5)
    assert.equal(
      await region.getByLabel('Componente del circuito', { exact: true }).inputValue(),
      'latch.mem_wb',
    )
    await until(
      async () => (await page.locator('.viewrv-selected-occurrence-line:visible').count()) === 0,
    )
    for (const cycle of [6, 7]) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await region.getByText(`Ciclo observado · ${cycle}`, { exact: true }).waitFor()
    }
    assert.equal(
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isDisabled(),
      true,
    )
    assert.equal(steps(), 7)
    const unchanged = await graphFrame.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph
      return (
        graph === window.__originalGraph &&
        graph.model === window.__originalModel &&
        JSON.stringify(
          Object.fromEntries(
            Object.entries(graph.model.cells)
              .filter(([, cell]) => !!cell.geometry)
              .map(([id, cell]) => [
                id,
                {
                  x: cell.geometry.x,
                  y: cell.geometry.y,
                  width: cell.geometry.width,
                  height: cell.geometry.height,
                },
              ]),
          ),
        ) === window.__originalGeometry
      )
    })
    assert.equal(unchanged, true, 'Updating captures reconstructed or moved the graph')
    await region
      .getByLabel('Componente del circuito', { exact: true })
      .selectOption('rf.register_file')
    await region.getByLabel('Formato de x1', { exact: true }).selectOption('unsigned')
    assert.equal(await region.getByLabel('Formato de x2', { exact: true }).inputValue(), 'hex')
    await page.screenshot({ path: resolve(gui, '../build/gui-pc-i07-inspector.png') })
    // The iframe must acquire document focus after the source editor had it.
    await page.locator('.monaco-editor [role="textbox"]').first().focus()
    await clickNativeCell(bindings.blocks['rf.register_file'])
    await menuCommand(page, 'Archivo', 'Cerrar tab')
    await until(
      async () => (await page.locator('iframe[title="Diagrama de la sesión"]').count()) === 0,
    )
    assert.equal(steps(), 7)
    await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
    await until(async () => {
      const f = await frame()
      return f && (await f.evaluate(() => !!window.tp3SessionAdapter))
    })
    assert.equal(steps(), 7)
    assert.deepEqual(errors, [])
    assert.deepEqual(external, [])
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    await until(() => !existsSync(resolve(root, 'viewrv/core.json')))
    console.log(
      'PC-I07 GUI: complete native GraphViewer, no initial snapshot/STEP, inferred activity, source/latch/diagram correlation, explicit occurrence follow/retirement, unchanged graph geometry/model, independent formats, dispose/reopen and no external resources passed. UART data is a fixed test-only trace.',
    )
  } catch (error) {
    if (page && !page.isClosed())
      await page
        .screenshot({ path: resolve(gui, '../build/gui-pc-i07-failure.png') })
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
    rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
