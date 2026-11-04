// Native GraphViewer verification of private XML/bindings edits, without a CPU/core.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const fs = require('node:fs')
const path = require('node:path')
const os = require('node:os')
const { pathToFileURL } = require('node:url')
const { execFileSync } = require('node:child_process')
const assert = require('node:assert/strict')
const { copyContent, editDrawing } = require('./drawing-fixture.cjs')
const gui = path.resolve(__dirname, '..'),
  temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-drawing-gui-')),
  content = path.join(temporary, 'content')
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
  let instance, page
  try {
    copyContent(path.resolve(gui, '../resources/content'), content)
    const edit = editDrawing(content),
      { ids } = edit
    execFileSync(process.execPath, [path.resolve(gui, '../packaging/build_viewer.cjs'), content], {
      stdio: 'pipe',
    })
    const main = path.join(temporary, 'main.cjs')
    fs.writeFileSync(
      main,
      `const {app,BrowserWindow}=require('electron');app.whenReady().then(()=>{const window=new BrowserWindow({width:1440,height:1000,webPreferences:{sandbox:true,nodeIntegration:false,contextIsolation:true,backgroundThrottling:false}});window.loadURL(process.env.VIEWRV_DRAWING);});app.on('window-all-closed',()=>app.quit());`,
    )
    const env = {
      ...process.env,
      XDG_RUNTIME_DIR: temporary,
      XDG_STATE_HOME: path.join(temporary, 'state'),
      XDG_DATA_HOME: path.join(temporary, 'data'),
      XDG_CONFIG_HOME: path.join(temporary, 'config'),
      VIEWRV_DRAWING: pathToFileURL(path.join(content, 'viewer/explore.html')).href,
    }
    instance = await electron.launch({
      executablePath: path.resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        main,
        '--disable-gpu',
        '--ozone-platform=x11',
        `--user-data-dir=${path.join(temporary, 'profile')}`,
      ],
      env,
    })
    page = await instance.firstWindow()
    await page.setViewportSize({ width: 1440, height: 1000 })
    const errors = [],
      external = []
    page.on('pageerror', (error) => errors.push(String(error)))
    page.on('request', (request) => {
      if (!/^(file:|data:|blob:)/.test(request.url())) external.push(request.url())
    })
    async function verify(view) {
      await page.waitForFunction(() => !!window.tp3Viewer, undefined, { timeout: 25000 })
      const measured = await page.evaluate(({ ids, point }) => {
        const graph = window.tp3Viewer.viewer.graph,
          data = window.tp3Viewer.data,
          root = graph.model.getCell(ids.root),
          field = graph.model.getCell(ids.field),
          wire = graph.model.getCell(ids.edge)
        const geometry = wire.geometry,
          points = [...(geometry.points || []), geometry.sourcePoint, geometry.targetPoint].filter(
            Boolean,
          )
        const camera = data.pages.find((page) => page.id === data.presentation.overview.id).camera
        return {
          x: root.geometry.x,
          y: root.geometry.y,
          fieldOwner: data.fields[ids.field].owner,
          wirePoint: points.some((value) => value.x === point.x && value.y === point.y),
          tooltip: graph.getTooltipForCell(field),
          camera,
          refresh: data.viewrv_refresh_cameras,
        }
      }, edit)
      assert.equal(measured.x, edit.rootX)
      assert.equal(measured.y, edit.rootY)
      assert.equal(measured.fieldOwner, ids.root)
      assert.equal(measured.wirePoint, true)
      assert.match(measured.tooltip, /valid/)
      assert.equal(measured.refresh, false)
      assert.ok(
        measured.camera.x <= edit.rootX && measured.camera.x + measured.camera.width >= edit.rootX,
        'Updated overview does not include the moved block',
      )
      assert.ok(
        measured.camera.width > 6350,
        'Overview camera still uses the original fixed rectangle',
      )
      if (view === 'explore') {
        await page.locator('#instruction-select').selectOption('add')
        await page.evaluate(() => window.tp3Viewer.chooseStage(0))
        assert.ok(
          await page.evaluate(
            (id) => window.tp3Viewer.data.pages.some((page) => page.components.includes(id)),
            ids.root,
          ),
        )
      } else {
        await page.waitForFunction(() => !!window.tp3SessionAdapter)
        await page.evaluate((block) => window.tp3SessionAdapter.setFocus([block]), ids.block)
        assert.equal(
          await page.evaluate((id) => {
            const g = window.tp3Viewer.viewer.graph
            return g.getCellStyle(g.model.getCell(id)).strokeColor
          }, ids.root),
          '#b80078',
        )
        for (let index = 0; index < 7; index++) await page.locator('#zoom-in').click()
        await page.evaluate(
          (block) => window.tp3SessionAdapter.selectComponent(block, { centre: true }),
          ids.block,
        )
        assert.equal(
          await page.evaluate((id) => {
            const g = window.tp3Viewer.viewer.graph
            return g.getCellStyle(g.model.getCell(id)).strokeColor
          }, ids.root),
          '#4338ca',
        )
        const point = await page.evaluate((id) => {
          const graph = window.tp3Viewer.viewer.graph,
            box = graph.view.getState(graph.model.getCell(id)).shape.node.getBoundingClientRect()
          return { x: box.x + box.width / 2, y: box.y + box.height / 2 }
        }, ids.field)
        await page.mouse.click(point.x, point.y)
        await until(() => page.evaluate((id) => window.tp3Viewer.selectedField === id, ids.field))
      }
      await page.screenshot({ path: path.resolve(gui, `../build/gui-pc-i07-drawing-${view}.png`) })
    }
    await verify('explore')
    await page.goto(
      pathToFileURL(path.join(content, 'viewer/session.html')).href + '#drawing-fixture',
    )
    await verify('session')
    const identity = await page.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph
      window.__keptGraph = graph
      window.__keptModel = graph.model
      return Object.keys(graph.model.cells).length
    })
    assert.ok(identity > 1700)
    await page.evaluate(() => window.tp3SessionAdapter.resize())
    assert.equal(
      await page.evaluate(
        () =>
          window.tp3Viewer.viewer.graph === window.__keptGraph &&
          window.tp3Viewer.viewer.graph.model === window.__keptModel,
      ),
      true,
    )
    // The same prepared viewer must consume corrected contextual prose, too.
    const educationFile = path.join(content, 'es/education.json'),
      education = JSON.parse(fs.readFileSync(educationFile, 'utf8'))
    education.modules['if.pc'].presentation.description = 'Explicación general de PC corregida.'
    education.instructions.add.module_explanations['ex.alu'] =
      'Explicación de ALU para ADD corregida.'
    education.instructions.add.stages[2].module_explanations['ex.alu'] =
      'Explicación de ALU en EX corregida.'
    fs.writeFileSync(educationFile, JSON.stringify(education))
    execFileSync(process.execPath, [path.resolve(gui, '../packaging/build_viewer.cjs'), content], {
      stdio: 'pipe',
    })
    await page.goto(pathToFileURL(path.join(content, 'viewer/explore.html')).href)
    await page.waitForFunction(() => !!window.tp3Viewer)
    const bindings = JSON.parse(
      fs.readFileSync(path.join(content, 'diagram_bindings.json'), 'utf8'),
    )
    const tooltip = (cell) =>
      page.evaluate((id) => {
        const graph = window.tp3Viewer.viewer.graph
        return graph.getTooltipForCell(graph.model.getCell(id))
      }, cell)
    assert.match(await tooltip(bindings.blocks['if.pc']), /Explicación general de PC corregida/)
    await page.locator('#instruction-select').selectOption('add')
    assert.match(await tooltip(bindings.blocks['ex.alu']), /Explicación de ALU para ADD corregida/)
    await page.locator('#mode-step').click()
    await page.evaluate(() => window.tp3Viewer.chooseStage(2))
    assert.match(await tooltip(bindings.blocks['ex.alu']), /Explicación de ALU en EX corregida/)
    const aluPoint = await page.evaluate((id) => {
      const graph = window.tp3Viewer.viewer.graph,
        box = graph.view.getState(graph.model.getCell(id)).shape.node.getBoundingClientRect()
      return { x: box.x + box.width / 2, y: box.y + box.height / 2 }
    }, bindings.blocks['ex.alu'])
    await page.mouse.click(aluPoint.x, aluPoint.y)
    await page
      .locator('#module-description')
      .filter({ hasText: 'Explicación de ALU en EX corregida.' })
      .waitFor()
    await page.screenshot({ path: path.resolve(gui, '../build/gui-pc-i07-drawing-text.png') })
    assert.deepEqual(errors, [])
    assert.deepEqual(external, [])

    await instance.close()
    instance = null
    console.log(
      'PC-I07 drawing: XML/bindings-only layout and ID edits render in both approved views; root, field, wire, tooltip, camera, conceptual route, functional/selection colors, native field click, editable global/instruction/stage prose and stable graph/model passed. No core or CPU commands were used.',
    )
  } catch (error) {
    if (page && !page.isClosed())
      await page
        .screenshot({ path: path.resolve(gui, '../build/gui-pc-i07-drawing-failure.png') })
        .catch(() => {})
    throw error
  } finally {
    if (instance) {
      await instance.evaluate(({ app }) => app.exit()).catch(() => {})
      await instance.close().catch(() => {})
    }
    fs.rmSync(temporary, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
