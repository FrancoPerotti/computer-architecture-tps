const { openConnection, closeConnection } = require('./ui-commands.cjs')
// TEST-PC-027/028: actual Electron, complete GraphViewer and a literal UART port.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn, execFileSync } = require('node:child_process')
const fs = require('node:fs'),
  os = require('node:os'),
  path = require('node:path'),
  assert = require('node:assert/strict')
const { menuCommand } = require('./ui-commands.cjs')
const probe = require('./performance-probe.cjs')
const gui = path.resolve(__dirname, '..'),
  tp3 = path.resolve(gui, '../..'),
  root = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-perf-'))
const output = fs.mkdtempSync(path.resolve(gui, '../build/performance-pc07-'))
const waylandDisplay = process.env.WAYLAND_DISPLAY
const waylandSocket =
  waylandDisplay &&
  (path.isAbsolute(waylandDisplay)
    ? waylandDisplay
    : process.env.XDG_RUNTIME_DIR && path.join(process.env.XDG_RUNTIME_DIR, waylandDisplay))
const useWayland = Boolean(waylandSocket && fs.existsSync(waylandSocket))
const env = {
  ...process.env,
  PYTHONPATH: tp3,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: path.join(root, 'state'),
  XDG_DATA_HOME: path.join(root, 'data'),
  XDG_CONFIG_HOME: path.join(root, 'config'),
  VIEWRV_TEST_CONTROL: root,
  ...(useWayland ? { WAYLAND_DISPLAY: waylandSocket } : {}),
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate, timeout = 25000) {
  const end = Date.now() + timeout
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await wait(25)
  }
  throw Error('Condition timed out')
}
async function finishTrace(cdp, output) {
  let timer
  const completed = new Promise((resolve, reject) => {
    cdp.once('Tracing.tracingComplete', resolve)
    timer = setTimeout(() => reject(Error('Trace completion timed out')), 15000)
  })
  try {
    const [, { stream }] = await Promise.all([cdp.send('Tracing.end'), completed])
    const trace = fs.openSync(path.join(output, 'chromium-timeline.json'), 'w')
    try {
      while (true) {
        const chunk = await cdp.send('IO.read', { handle: stream })
        fs.writeSync(trace, chunk.base64Encoded ? Buffer.from(chunk.data, 'base64') : chunk.data)
        if (chunk.eof) break
      }
    } finally {
      fs.closeSync(trace)
    }
    await cdp.send('IO.close', { handle: stream })
  } finally {
    clearTimeout(timer)
  }
}
const report = {
  created_at: new Date().toISOString(),
  method: {
    point:
      'Input event to corresponding DOM/SVG state and subsequent animation frame; conservative visible-response bound, not a photodiode measurement.',
    cadence:
      'Trusted CDP pointer/wheel inputs scheduled at 60 Hz, with all requested/delivered inputs retained. Every requestAnimationFrame interval with native camera positions; 25 ms flags a missed 60 Hz interval. Retain all raw samples and long-task records. CDP timeline recorded separately from any optional video.',
    hardware: 'Named literal UART fixture, real assembler/core/HTTP/SSE. No FPGA acceptance.',
  },
  output,
  configurations: [],
  motions: [],
  records: [],
  incidents: [],
  motion_coverage_failures: [],
}
const save = () =>
  fs.writeFileSync(path.join(output, 'performance.json'), JSON.stringify(report, null, 2) + '\n')
;(async () => {
  const core = spawn(
    path.resolve(gui, '../.venv/bin/python'),
    ['-m', 'software.tests.viewrv.educational_core'],
    { cwd: tp3, env, stdio: ['ignore', 'ignore', 'pipe'] },
  )
  let instance,
    page,
    cdp,
    traceStarted = false
  try {
    await until(() => fs.existsSync(path.join(root, 'viewrv/core.json')))
    const source = path.join(root, 'performance source.s'),
      scratch = path.join(root, 'latency scratch.s')
    fs.writeFileSync(source, 'addi x1,x0,5\naddi x2,x0,2\nadd x2,x1,x1\nhalt\n')
    fs.writeFileSync(scratch, '')
    const steps = () =>
      fs
        .readFileSync(path.join(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    const recording = process.env.VIEWRV_PERF_VIDEO === '1'
    instance = await electron.launch({
      executablePath: path.resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        gui,
        `--ozone-platform=${useWayland ? 'wayland' : 'x11'}`,
        ...(process.env.VIEWRV_PERF_SOFTWARE === '1' ? ['--disable-gpu'] : []),
        `--user-data-dir=${path.join(root, 'profile')}`,
      ],
      env,
      timeout: 30000,
    })
    page = await instance.firstWindow()
    await page.setViewportSize({ width: 1366, height: 768 })
    report.environment = await instance.evaluate(async ({ app, screen, powerMonitor }) => {
      const display = screen.getPrimaryDisplay()
      return {
        app_version: app.getVersion(),
        electron: process.versions.electron,
        chrome: process.versions.chrome,
        node: process.versions.node,
        platform: process.platform,
        arch: process.arch,
        gpu_features: app.getGPUFeatureStatus(),
        gpu_info: await app.getGPUInfo('basic'),
        display: {
          size: display.size,
          scaleFactor: display.scaleFactor,
          displayFrequency: display.displayFrequency,
        },
        on_battery: powerMonitor.isOnBatteryPower(),
      }
    })
    report.environment.cpu = os.cpus()[0].model
    report.environment.logical_cpus = os.cpus().length
    report.environment.memory_bytes = os.totalmem()
    report.environment.kernel = os.release()
    report.environment.video_recording = recording
    report.environment.video_method = recording
      ? 'CDP JPEG screencast every fourth display frame; timestamps retained, encoded VFR after measurement. Capture overhead is included.'
      : null
    report.environment.launch_software_flag = process.env.VIEWRV_PERF_SOFTWARE === '1'
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
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
    const diagram = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true })
    await diagram.waitFor()
    const getFrame = async (title = 'Diagrama de la sesión') => {
      const element = await page.locator(`iframe[title="${title}"]`).elementHandle()
      return element.contentFrame()
    }
    let frame
    await until(async () => {
      frame = await getFrame()
      return frame && (await frame.evaluate(() => !!window.tp3SessionAdapter))
    })
    const bindings = JSON.parse(
      fs.readFileSync(path.resolve(gui, '../resources/content/diagram_bindings.json'), 'utf8'),
    )
    await probe.installMain(page)
    await probe.installFrame(frame, bindings)
    await frame.evaluate(() => {
      const graph = window.tp3Viewer.viewer.graph
      window.__perfGraph = graph
      window.__perfModel = graph.model
      window.__perfGeometry = JSON.stringify(
        Object.fromEntries(
          Object.entries(graph.model.cells)
            .filter(([, cell]) => cell.geometry)
            .map(([id, cell]) => [id, cell.geometry]),
        ),
      )
    })
    await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
    await diagram.getByText('Ciclo observado · 1', { exact: true }).waitFor()
    await page.getByRole('tab', { name: /performance source.s/ }).click()
    await instance.evaluate(({ dialog }, scratch) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [scratch] })
    }, scratch)
    await menuCommand(page, 'Archivo', 'Abrir programa…')
    await page.getByRole('tab', { name: 'latency scratch.s', exact: true }).waitFor()
    while (await page.getByRole('button', { name: 'Cerrar notificación', exact: true }).count())
      await page.getByRole('button', { name: 'Cerrar notificación', exact: true }).first().click()
    cdp = await page.context().newCDPSession(page)
    const videoFrames = []
    if (recording) {
      fs.mkdirSync(path.join(output, 'frames'))
      cdp.on('Page.screencastFrame', (event) => {
        const name = `frames/${String(videoFrames.length).padStart(6, '0')}.jpg`
        fs.writeFileSync(path.join(output, name), Buffer.from(event.data, 'base64'))
        videoFrames.push({ name, timestamp: event.metadata.timestamp })
        void cdp.send('Page.screencastFrameAck', { sessionId: event.sessionId }).catch(() => {})
      })
      await cdp.send('Page.startScreencast', {
        format: 'jpeg',
        quality: 75,
        maxWidth: 1366,
        maxHeight: 768,
        everyNthFrame: 4,
      })
    }
    await cdp.send('Tracing.start', {
      categories: 'devtools.timeline,disabled-by-default-devtools.timeline.frame,blink.user_timing',
      transferMode: 'ReturnAsStream',
    })
    traceStarted = true
    async function pointActions(label) {
      await page.evaluate((label) => {
        window.__viewrvPerformance.condition = label
      }, label)
      const expectedStart = await page.evaluate(() => window.__viewrvPerformance.records.length)
      await page.getByRole('tab', { name: 'latency scratch.s', exact: true }).click()
      const editor = page.locator('.monaco-editor:visible [role="textbox"]').first()
      await editor.focus()
      await page.keyboard.press('Control+End')
      await page.keyboard.press('Enter')
      await page.evaluate(() => {
        window.__viewrvPerformance.expected = ''
        window.__viewrvPerformance.typing = true
      })
      const sample = label.startsWith('waiting') ? '# uart wait' : '# latency sample'
      await page.keyboard.type(sample, {
        delay: 35,
      })
      await page.evaluate(() => {
        window.__viewrvPerformance.typing = false
      })
      for (let index = 0; index < 4; index++) {
        await page.getByRole('tab', { name: /performance source.s/ }).click()
        await page.getByRole('tab', { name: 'latency scratch.s', exact: true }).click()
      }
      for (const block of [
        'rf.register_file',
        'latch.if_id',
        'ex.alu',
        'latch.id_ex',
        'latch.ex_mem',
        'mem.data_memory',
        'latch.mem_wb',
        'if.pc',
      ]) {
        const before = await page.evaluate(
          () => window.__viewrvPerformance.records.filter((row) => row.kind === 'module').length,
        )
        await diagram.getByLabel('Componente del circuito', { exact: true }).selectOption(block)
        await until(
          async () =>
            (await page.evaluate(
              () =>
                window.__viewrvPerformance.records.filter((row) => row.kind === 'module').length,
            )) > before,
        )
      }
      await until(
        async () => (await page.evaluate(() => window.__viewrvPerformance.pending.size)) === 0,
      )
      await frame.evaluate(
        () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
      )
      const counts = await page.evaluate(
        (start) =>
          window.__viewrvPerformance.records.slice(start).reduce((out, row) => {
            out[row.kind] = (out[row.kind] || 0) + 1
            return out
          }, {}),
        expectedStart,
      )
      assert.ok(
        counts.typing === sample.length && counts.tab >= 8 && counts.module === 8,
        'Missing corresponding point-response samples',
      )
    }
    async function motion(label, frame) {
      await frame.locator('#fit').click()
      for (let index = 0; index < 3; index++) await frame.locator('#zoom-in').click()
      await probe.startMotion(frame, label + '-pan')
      const point = await frame.evaluate(() => {
        const canvas = document.getElementById('diagram'),
          box = canvas.getBoundingClientRect()
        for (let y = 70; y < box.height - 70; y += 35)
          for (let x = 90; x < box.width - 90; x += 35) {
            const node = document.elementFromPoint(box.x + x, box.y + y)
            if (node && (node === canvas || node.tagName.toLowerCase() === 'svg'))
              return { x: box.x + x, y: box.y + y }
          }
        return { x: box.x + 90, y: box.y + 70 }
      })
      const frameBounds = await frame.locator('html').boundingBox()
      const canvasBounds = await frame.locator('#diagram').boundingBox()
      await page.mouse.move(frameBounds.x + point.x, frameBounds.y + point.y)
      await page.mouse.down()
      async function pacedInputs(count, createEvent) {
        const pending = [],
          schedule = [],
          start = performance.now()
        for (let index = 0; index < count; index++) {
          const target = start + (index * 1000) / 60,
            delay = target - performance.now()
          if (delay > 0) await wait(delay)
          const sent = performance.timeOrigin + performance.now()
          pending.push(
            cdp.send('Input.dispatchMouseEvent', createEvent(index)).then(() =>
              schedule.push({
                index,
                sent_ms: sent,
                ack_ms: performance.timeOrigin + performance.now(),
              }),
            ),
          )
        }
        await Promise.all(pending)
        return schedule.sort((a, b) => a.index - b.index)
      }
      const panInputs = await pacedInputs(90, (index) => {
        const angle = ((index + 1) / 90) * Math.PI * 2
        return {
          type: 'mouseMoved',
          x: frameBounds.x + point.x + 55 * Math.sin(angle),
          y: frameBounds.y + point.y + 30 * (1 - Math.cos(angle)),
          button: 'left',
          buttons: 1,
        }
      })
      await page.mouse.up()
      const pan = await probe.stopMotion(frame)
      pan.requested_inputs = panInputs
      pan.summary = probe.motionSummary(pan)
      report.motions.push(pan)
      await probe.startMotion(frame, label + '-zoom')
      const zoomX = canvasBounds.x + canvasBounds.width / 2
      const zoomY = canvasBounds.y + canvasBounds.height / 2
      await page.mouse.move(zoomX, zoomY)
      await page.keyboard.down('Control')
      const zoomInputs = await pacedInputs(60, (index) => ({
        type: 'mouseWheel',
        x: zoomX,
        y: zoomY,
        deltaX: 0,
        deltaY: index < 30 ? -8 : 8,
        modifiers: 2,
      }))
      await page.keyboard.up('Control')
      await frame.evaluate(
        () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))),
      )
      const zoom = await probe.stopMotion(frame)
      zoom.requested_inputs = zoomInputs
      zoom.summary = probe.motionSummary(zoom)
      report.motions.push(zoom)
      if (
        pan.summary.frames_with_camera_change <= 20 ||
        zoom.summary.frames_with_camera_change <= 10
      )
        report.motion_coverage_failures.push(label)
      save()
    }
    const configurations =
      process.env.VIEWRV_PERF_QUICK === '1'
        ? [{ width: 1366, height: 768, zoom: 1 }]
        : [
            { width: 1366, height: 768, zoom: 1 },
            { width: 1920, height: 1080, zoom: 1 },
            { width: 1366, height: 768, zoom: 1.25 },
          ]
    for (const [index, configuration] of configurations.entries()) {
      await page.setViewportSize({ width: configuration.width, height: configuration.height })
      await instance.evaluate(
        ({ BrowserWindow }, zoom) =>
          BrowserWindow.getAllWindows()[0].webContents.setZoomFactor(zoom),
        configuration.zoom,
      )
      const condition = 'normal-' + index
      report.configurations.push({
        ...configuration,
        condition,
        actual_viewport: await page.evaluate(() => ({
          width: innerWidth,
          height: innerHeight,
          devicePixelRatio,
        })),
      })
      await pointActions(condition)
      await motion(condition, frame)
      await page.screenshot({ path: path.join(output, `normal-${index}.png`) })
    }
    assert.equal(
      await frame.evaluate(() => {
        const graph = window.tp3Viewer.viewer.graph
        return (
          graph === window.__perfGraph &&
          graph.model === window.__perfModel &&
          JSON.stringify(
            Object.fromEntries(
              Object.entries(graph.model.cells)
                .filter(([, cell]) => cell.geometry)
                .map(([id, cell]) => [id, cell.geometry]),
            ),
          ) === window.__perfGeometry
        )
      }),
      true,
    )
    assert.equal(steps(), 1, 'Point interactions and motion issued extra STEP')
    const beforeRun = steps()
    await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
    await page.getByRole('tab', { name: /performance source.s/ }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Correr', exact: true }).isEnabled())
    fs.writeFileSync(path.join(root, 'run.wait'), 'wait')
    await page.getByRole('button', { name: 'Correr', exact: true }).click()
    await page.getByRole('button', { name: 'Detener ejecución (RESET)', exact: true }).waitFor()
    await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
    await until(async () => {
      frame = await getFrame()
      return frame && (await frame.evaluate(() => !!window.tp3SessionAdapter))
    })
    await probe.installFrame(frame, bindings)
    await diagram
      .getByText('Sin captura completa. Los valores no se presumen cero.', { exact: true })
      .waitFor()
    await pointActions('waiting-serial')
    await motion('waiting-serial', frame)
    assert.equal(
      steps(),
      beforeRun,
      'Navigation/motion issued extra CPU cycles while RUN was pending',
    )
    await page.getByRole('button', { name: 'Detener ejecución (RESET)', exact: true }).click()
    await page.getByText('Sin programa cargado', { exact: true }).waitFor()
    await instance.evaluate(({ BrowserWindow }) =>
      BrowserWindow.getAllWindows()[0].webContents.setZoomFactor(1),
    )
    await page.getByRole('button', { name: 'Visor interactivo', exact: true }).click()
    const explore = await getFrame('Visor interactivo del pipeline')
    await explore.waitForFunction(() => !!window.tp3Viewer)
    await motion('conceptual', explore)
    report.records = await page.evaluate(() => window.__viewrvPerformance.records)
    report.errors = errors
    report.point_first_and_repeated = {}
    for (const kind of ['typing', 'tab', 'module']) {
      const samples = report.records.filter((row) => row.kind === kind)
      report.point_first_and_repeated[kind] = {
        first_in_run: samples[0],
        repeated: probe.summarize(samples.slice(1).map((row) => row.latency_ms)),
      }
    }
    report.method.first_use =
      'First observed interaction per category in a fresh app/core run, followed by repeated use. This is not an OS-cache cold-boot measurement.'
    report.point_summary = {}
    for (const kind of ['typing', 'tab', 'module', 'observation-apply'])
      report.point_summary[kind] = probe.summarize(
        report.records.filter((row) => row.kind === kind).map((row) => row.latency_ms),
      )
    report.incidents = report.records.filter((row) => row.error || row.latency_ms >= 100)
    report.motion_incidents = report.motions.flatMap((motion) =>
      motion.summary.intervals_over_25_ms.map((row) => ({ motion: motion.label, ...row })),
    )
    await finishTrace(cdp, output)
    traceStarted = false
    if (recording) {
      await cdp.send('Page.stopScreencast')
      report.video_frames = videoFrames
      const lines = ['ffconcat version 1.0']
      for (let index = 0; index < videoFrames.length; index++) {
        const row = videoFrames[index]
        lines.push(`file '${row.name}'`)
        if (index + 1 < videoFrames.length)
          lines.push(
            `duration ${Math.max(0.001, videoFrames[index + 1].timestamp - row.timestamp)}`,
          )
      }
      fs.writeFileSync(path.join(output, 'recording.ffconcat'), lines.join('\n') + '\n')
      execFileSync(
        'ffmpeg',
        [
          '-hide_banner',
          '-loglevel',
          'error',
          '-y',
          '-safe',
          '0',
          '-i',
          'recording.ffconcat',
          '-fps_mode',
          'vfr',
          '-c:v',
          'libvpx-vp9',
          '-crf',
          '35',
          '-b:v',
          '0',
          'recording.webm',
        ],
        { cwd: output, timeout: 120000 },
      )
    }
    save()
    assert.deepEqual(errors, [])
    assert.deepEqual(
      report.motion_coverage_failures,
      [],
      'Motion input did not move the native camera',
    )
    assert.equal(
      report.incidents.length,
      0,
      'Visible responses reached 100 ms; all incidents are preserved',
    )
    assert.equal(
      report.motion_incidents.length,
      0,
      'Long frame intervals detected; inspect all raw samples and the timeline',
    )
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    await until(() => !fs.existsSync(path.join(root, 'viewrv/core.json')))
    report.status = 'passed'
    save()
    console.log(
      JSON.stringify({
        output,
        status: report.status,
        points: report.point_summary,
        motions: report.motions.map((row) => ({ label: row.label, ...row.summary })),
        gpu: report.environment.gpu_features.gpu_compositing,
      }),
    )
  } catch (error) {
    report.status = 'failed'
    report.failure = String(error.stack || error)
    if (traceStarted && cdp) {
      await finishTrace(cdp, output).catch((error) => {
        report.trace_error = String(error)
      })
      traceStarted = false
    }
    if (page && !page.isClosed()) {
      report.records = await page
        .evaluate(() => window.__viewrvPerformance?.records || [])
        .catch(() => report.records)
      await page.screenshot({ path: path.join(output, 'failure.png') }).catch(() => {})
    }
    save()
    throw error
  } finally {
    if (traceStarted && cdp) await cdp.send('Tracing.end').catch(() => {})
    if (instance) {
      await instance.evaluate(({ app }) => app.exit()).catch(() => {})
      await instance.close().catch(() => {})
    }
    if (core.exitCode === null && core.signalCode === null) {
      const exited = new Promise((resolve) => core.once('exit', resolve)),
        killTimer = setTimeout(() => core.kill('SIGKILL'), 5000)
      core.kill('SIGTERM')
      await exited
      clearTimeout(killTimer)
    }
    fs.rmSync(root, { recursive: true, force: true })
  }
})().catch((error) => {
  console.error(error)
  console.error('All samples retained at ' + output)
  process.exitCode = 1
})
