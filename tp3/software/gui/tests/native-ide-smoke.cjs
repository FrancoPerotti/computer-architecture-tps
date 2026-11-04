const { waitForCore } = require('./ui-commands.cjs')
// TEST-PC-002/012/013/017/026: actual ASAR GUI + native core/CLI, no hardware fixtures.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { mkdtempSync, readFileSync, writeFileSync, existsSync, rmSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const { execFileSync } = require('node:child_process')
const { menuCommand } = require('./ui-commands.cjs')
const assert = require('node:assert/strict')
const gui = resolve(__dirname, '..'),
  product = process.env.VIEWRV_PRODUCT
if (!product || !existsSync(resolve(product, 'VERIFICATION-ONLY.txt')))
  throw Error('Indicá la disposición nativa de comprobación, no una distribución anterior.')
const root = mkdtempSync(resolve(tmpdir(), 'viewrv-pc06-native-ide-'))
const environment = {
  ...process.env,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  XDG_DATA_HOME: resolve(root, 'data'),
}
for (const name of ['PYTHONPATH', 'PYTHONHOME', 'LD_LIBRARY_PATH', 'LD_PRELOAD'])
  delete environment[name]
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate, timeout = 18000) {
  const end = Date.now() + timeout
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await delay(40)
  }
  throw Error('Condition timed out')
}
function cli(...args) {
  return JSON.parse(
    execFileSync(resolve(product, 'viewrv'), ['--output', 'json', ...args], {
      cwd: root,
      env: environment,
      encoding: 'utf8',
      timeout: 20000,
    }),
  )
}
;(async () => {
  let instance, corePid
  try {
    assert.equal(existsSync(resolve(product, 'release.json')), false)
    assert.equal(existsSync(resolve(product, 'resources/hardware/processor.bit')), false)
    instance = await electron.launch({
      executablePath: resolve(product, 'viewrv-gui'),
      args: [
        '--disable-gpu',
        '--ozone-platform=x11',
        `--user-data-dir=${resolve(root, 'profile')}`,
      ],
      env: environment,
    })
    const page = await instance.firstWindow()
    await page.setViewportSize({ width: 1366, height: 768 })
    const errors = [],
      external = []
    page.on('pageerror', (error) => errors.push(String(error)))
    page.on('request', (req) => {
      if (!/^(viewrv:|blob:|data:|http:\/\/127\.0\.0\.1:)/.test(req.url())) external.push(req.url())
    })
    await waitForCore(page)
    const parent = instance.process().pid
    for (const value of readFileSync(`/proc/${parent}/task/${parent}/children`, 'utf8')
      .trim()
      .split(/\s+/)) {
      try {
        if (
          readFileSync(`/proc/${value}/cmdline`, 'utf8').split('\0')[0] ===
          resolve(product, 'resources/core/viewrv-core')
        )
          corePid = Number(value)
      } catch {}
    }
    assert.ok(corePid, 'Packaged host did not start its native core')
    const info = await instance.evaluate(({ app }) => ({
      packaged: app.isPackaged,
      version: app.getVersion(),
    }))
    assert.deepEqual(info, {
      packaged: true,
      version: JSON.parse(readFileSync(resolve(gui, 'package.json'), 'utf8')).version,
    })
    await page.getByRole('button', { name: 'Visor interactivo', exact: true }).click()
    const iframe = page.locator('iframe').first()
    await iframe.waitFor()
    const conceptual = await (await iframe.elementHandle()).contentFrame()
    await until(() => conceptual.evaluate(() => !!window.tp3Viewer))
    const instructions = await conceptual.evaluate(() =>
      Object.keys(window.tp3Viewer.data.instructions),
    )
    assert.equal(instructions.length, 33)
    await conceptual.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph
      window.__nativeGraph = graph
      window.__nativeModel = graph.model
      window.__nativeGeometry = JSON.stringify(
        Object.fromEntries(
          Object.entries(graph.model.cells)
            .filter(([, cell]) => cell.geometry)
            .map(([id, cell]) => [id, cell.geometry]),
        ),
      )
    })
    await conceptual.locator('#instruction-select').selectOption(instructions[0])
    await conceptual.locator('#mode-step').click()
    let stageCount = 0
    for (const instruction of instructions) {
      await conceptual.locator('#instruction-select').selectOption(instruction)
      console.log('Conceptual native audit: ' + instruction)
      for (let stage = 0; stage < 5; stage++) {
        const shown = await conceptual.evaluate(async (stage) => {
          const p = window.tp3Viewer
          p.chooseStage(stage)
          await new Promise((resolve) =>
            requestAnimationFrame(() => requestAnimationFrame(resolve)),
          )
          const selected = p.data.pages[p.selected],
            expected = p.data.instructions[p.instruction].stages[stage]
          return {
            stage: p.stage,
            selected: selected.id,
            expected: expected.id,
            operation: document.getElementById('stage-operation').textContent,
            expectedOperation: selected.operation,
            components: selected.components.every((id) => !!p.viewer.graph.model.getCell(id)),
          }
        }, stage)
        assert.equal(shown.stage, stage)
        assert.equal(shown.selected, shown.expected)
        assert.equal(shown.operation, shown.expectedOperation)
        assert.equal(shown.components, true)
        stageCount++
      }
    }
    assert.equal(stageCount, 165)
    assert.equal(
      await conceptual.evaluate(() => {
        const g = window.tp3Viewer.viewer.graph
        return (
          g === window.__nativeGraph &&
          g.model === window.__nativeModel &&
          JSON.stringify(
            Object.fromEntries(
              Object.entries(g.model.cells)
                .filter(([, cell]) => cell.geometry)
                .map(([id, cell]) => [id, cell.geometry]),
            ),
          ) === window.__nativeGeometry
        )
      }),
      true,
    )
    await conceptual.locator('#instruction-select').selectOption('add')
    await conceptual.evaluate(() => window.tp3Viewer.chooseStage(2))
    await page.screenshot({
      path: resolve(
        gui,
        `../build/${process.env.VIEWRV_EVIDENCE_PREFIX || 'gui-pc-i06'}-native-conceptual.png`,
      ),
    })
    const source = resolve(root, 'native program.s')
    writeFileSync(source, 'addi x1,x0,5\nhalt\n')
    const translation = cli('program', 'assemble', source)
    assert.equal(translation.error, null)
    assert.deepEqual(translation.result.image, [147, 0, 80, 0, 11, 0, 0, 0])
    await instance.evaluate(({ dialog }, source) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [source] })
    }, source)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir programa…')
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    let assemblyRequests = 0
    page.on('request', (req) => {
      if (req.url().endsWith('/program/assemble')) assemblyRequests++
    })
    await page.keyboard.press('Control+Shift+Enter')
    await page.getByText('Conectá la FPGA y comprobá la comunicación', { exact: true }).waitFor()
    assert.equal(assemblyRequests, 0, 'Keyboard shortcut bypassed the disabled combined action')
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await page.getByRole('button', { name: 'Ver ensamblado', exact: true }).waitFor()
    await page.getByRole('button', { name: 'Ver ensamblado', exact: true }).click()
    await page.getByRole('heading', { name: 'Vista ensamblada', exact: true }).waitFor()
    await page.getByText('0x00500093', { exact: true }).waitFor()
    assert.equal(await page.getByRole('button', { name: 'Cargar', exact: true }).isDisabled(), true)
    await page.getByText('native program.s', { exact: true }).first().click()
    await menuCommand(page, 'Ver', 'Dividir izquierda/derecha')
    await page.locator('.monaco-editor [role="textbox"]').last().focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# native ASAR edit\n')
    await menuCommand(page, 'Archivo', 'Guardar')
    await until(() => readFileSync(source, 'utf8').includes('# native ASAR edit'))
    await page.screenshot({
      path: resolve(
        gui,
        `../build/${process.env.VIEWRV_EVIDENCE_PREFIX || 'gui-pc-i06'}-native.png`,
      ),
    })
    assert.equal(cli('board', 'status').result.preparation_required, true)
    assert.deepEqual(external, [])
    assert.deepEqual(errors, [])
    const closed = page.waitForEvent('close', { timeout: 15000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    const guiProcess = instance.process()
    await until(() => guiProcess.exitCode !== null || guiProcess.signalCode !== null, 10000)
    assert.equal(guiProcess.exitCode, 0)
    // The packaged app has exited normally; do not send another app.quit RPC
    // through its now-dead Node inspector connection.
    instance = null
    assert.ok(cli('work', 'status').result.work_id, 'Closing GUI terminated the CLI work')
    cli('work', 'finish')
    await until(() => !existsSync(resolve(root, 'viewrv/core.json')))
    return 'Native verification: 33 conceptual instructions / 165 stages with stable graph/model/geometry; packaged ASAR host started native core; native CLI and real assembler, GUI assembly view, shared editor split/save, local resources and independent close passed. No hardware distribution or FPGA execution claimed.\n'
  } finally {
    if (instance) {
      const child = instance.process()
      if (child.exitCode === null && child.signalCode === null) child.kill('SIGTERM')
    }
    if (corePid) {
      try {
        if (
          readFileSync(`/proc/${corePid}/cmdline`, 'utf8').split('\0')[0] ===
          resolve(product, 'resources/core/viewrv-core')
        )
          process.kill(corePid, 'SIGTERM')
      } catch {}
    }
    rmSync(root, { recursive: true, force: true })
  }
})()
  .then((message) => process.stdout.write(message, () => process.exit(0)))
  .catch((error) =>
    process.stderr.write(String(error.stack || error) + '\n', () => process.exit(1)),
  )
