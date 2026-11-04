// Test instrumentation only. Keep every sample, including failures and outliers.
async function installMain(page) {
  await page.evaluate(() => {
    const probe = (window.__viewrvPerformance = {
      records: [],
      condition: 'normal',
      typing: false,
      expected: '',
      pending: new Map(),
    })
    const now = () => performance.timeOrigin + performance.now()
    const finish = (kind, start, check, detail) => {
      let frames = 0
      const poll = () => {
        frames++
        if (check()) {
          requestAnimationFrame(() =>
            probe.records.push({
              kind,
              condition: probe.condition,
              start_ms: start,
              end_ms: now(),
              latency_ms: now() - start,
              detail,
              frames,
            }),
          )
        } else if (now() - start > 1500)
          probe.records.push({
            kind,
            condition: probe.condition,
            start_ms: start,
            error: 'Corresponding visible response did not appear',
            detail,
          })
        else requestAnimationFrame(poll)
      }
      requestAnimationFrame(poll)
    }
    document.addEventListener(
      'keydown',
      (event) => {
        if (
          !probe.typing ||
          event.ctrlKey ||
          event.metaKey ||
          event.altKey ||
          event.key.length !== 1
        )
          return
        probe.expected += event.key
        const expected = probe.expected
        finish(
          'typing',
          performance.timeOrigin + event.timeStamp,
          () =>
            Array.from(document.querySelectorAll('.monaco-editor .view-lines')).some(
              (node) =>
                node.getBoundingClientRect().width > 0 &&
                node.innerText.replaceAll('\u00a0', ' ').includes(expected),
            ),
          { expected },
        )
      },
      true,
    )
    document.addEventListener(
      'pointerdown',
      (event) => {
        const tab = event.target.closest?.('[role="tab"]')
        if (!tab || tab.getAttribute('aria-selected') === 'true') return
        finish(
          'tab',
          performance.timeOrigin + event.timeStamp,
          () =>
            tab.getAttribute('aria-selected') === 'true' &&
            !!document.getElementById(tab.getAttribute('aria-controls'))?.getBoundingClientRect()
              .width,
          { label: tab.getAttribute('aria-label') },
        )
      },
      true,
    )
    document.addEventListener(
      'change',
      (event) => {
        if (event.target.getAttribute('aria-label') !== 'Componente del circuito') return
        const block = event.target.value
        probe.pending.set(block, {
          start_ms: performance.timeOrigin + event.timeStamp,
          condition: probe.condition,
        })
      },
      true,
    )
    window.addEventListener('message', (event) => {
      if (
        event.source !==
          document.querySelector('iframe[title="Diagrama de la sesión"]')?.contentWindow ||
        event.data?.channel !== 'viewrv-performance-probe'
      )
        return
      const value = event.data
      if (value.kind === 'module-complete') {
        const pending = probe.pending.get(value.block)
        if (!pending) return
        probe.records.push({
          kind: 'module',
          condition: pending.condition,
          start_ms: pending.start_ms,
          end_ms: value.at_ms,
          latency_ms: value.at_ms - pending.start_ms,
          detail: { block: value.block },
          error: value.error,
          debug: value.debug,
        })
        probe.pending.delete(value.block)
      } else if (value.kind === 'observation-complete')
        probe.records.push({
          kind: 'observation-apply',
          condition: probe.condition,
          start_ms: value.start_ms,
          end_ms: value.at_ms,
          latency_ms: value.at_ms - value.start_ms,
          detail: { cycle: value.cycle },
          error: value.error,
        })
    })
  })
}
async function installFrame(frame, bindings) {
  await frame.evaluate((bindings) => {
    const graph = window.tp3Viewer.viewer.graph
    const now = () => performance.timeOrigin + performance.now()
    const post = (value) =>
      parent.postMessage({ channel: 'viewrv-performance-probe', ...value }, '*')
    window.addEventListener('message', (event) => {
      const value = event.data
      if (event.source !== parent || value?.channel !== 'viewrv-graph-v1') return
      if (value.kind === 'select') {
        const block = value.block_id,
          id = bindings.representations?.[block]?.[0] || bindings.blocks[block],
          start = now()
        const poll = () => {
          const render = graph.view.getState(graph.model.getCell(id))
          const painted =
            render?.style.strokeColor === '#4338ca' &&
            [render.shape.node, ...render.shape.node.querySelectorAll('[stroke]')].some((node) => {
              const stroke = getComputedStyle(node).stroke
              return stroke === 'rgb(67, 56, 202)' || stroke === '#4338ca'
            })
          if (painted)
            requestAnimationFrame(() =>
              requestAnimationFrame(() => post({ kind: 'module-complete', block, at_ms: now() })),
            )
          else if (now() - start > 1500)
            post({
              kind: 'module-complete',
              block,
              at_ms: now(),
              error: 'Native selection stroke did not appear',
              debug: {
                style: render?.style,
                shape: render?.shape?.node?.outerHTML?.slice(0, 3000),
              },
            })
          else requestAnimationFrame(poll)
        }
        requestAnimationFrame(poll)
      } else if (value.kind === 'observation' && value.context.observation) {
        const start = performance.timeOrigin + event.timeStamp,
          cycle = value.context.observation.snapshot.cycle_count
        requestAnimationFrame(() =>
          requestAnimationFrame(() =>
            post({ kind: 'observation-complete', start_ms: start, at_ms: now(), cycle }),
          ),
        )
      }
    })
  }, bindings)
}
async function startMotion(frame, label) {
  await frame.evaluate((label) => {
    const graph = window.tp3Viewer.viewer.graph,
      records = [],
      longTasks = [],
      longFrames = [],
      inputs = [],
      start = performance.mark('viewrv-' + label + '-start')
    let previous = null,
      handle = 0
    const input = (event) =>
      inputs.push({
        type: event.type,
        at_ms: event.timeStamp,
        delivered_ms: performance.now(),
        x: event.clientX,
        y: event.clientY,
        deltaY: event.deltaY,
        buttons: event.buttons,
      })
    document.addEventListener('pointermove', input, true)
    document.addEventListener('wheel', input, true)
    const sample = (time) => {
      records.push({
        at_ms: time,
        interval_ms: previous === null ? null : time - previous,
        scale: graph.view.scale,
        x: graph.container.scrollLeft,
        y: graph.container.scrollTop,
      })
      previous = time
      handle = requestAnimationFrame(sample)
    }
    const observers = []
    for (const [type, target] of [
      ['longtask', longTasks],
      ['long-animation-frame', longFrames],
    ]) {
      if (!PerformanceObserver.supportedEntryTypes.includes(type)) continue
      const observer = new PerformanceObserver((list) => {
        for (const entry of list.getEntries()) target.push(entry.toJSON())
      })
      observer.observe({ type })
      observers.push(observer)
    }
    handle = requestAnimationFrame(sample)
    window.__viewrvMotion = {
      label,
      records,
      longTasks,
      longFrames,
      stop() {
        cancelAnimationFrame(handle)
        document.removeEventListener('pointermove', input, true)
        document.removeEventListener('wheel', input, true)
        for (const observer of observers) observer.disconnect()
        performance.mark('viewrv-' + label + '-end')
        return {
          label,
          start_mark_ms: start.startTime,
          time_origin_ms: performance.timeOrigin,
          records,
          inputs,
          long_tasks: longTasks,
          long_animation_frames: longFrames,
        }
      },
    }
  }, label)
}
async function stopMotion(frame) {
  return frame.evaluate(() => window.__viewrvMotion.stop())
}
function summarize(values) {
  const samples = values.filter((value) => typeof value === 'number').sort((a, b) => a - b)
  if (!samples.length) return { count: 0 }
  return {
    count: samples.length,
    min_ms: samples[0],
    median_ms: samples[Math.floor((samples.length - 1) * 0.5)],
    p95_ms: samples[Math.floor((samples.length - 1) * 0.95)],
    p99_ms: samples[Math.floor((samples.length - 1) * 0.99)],
    max_ms: samples.at(-1),
  }
}
function motionSummary(motion) {
  const records = motion.records,
    issues = records.flatMap((row, index) =>
      row.interval_ms > 25
        ? [
            {
              index,
              ...row,
              estimated_missed_60hz_frames: Math.max(
                0,
                Math.round(row.interval_ms / (1000 / 60)) - 1,
              ),
            },
          ]
        : [],
    )
  const changes = records.filter(
    (row, index) =>
      index && ['x', 'y', 'scale'].some((key) => row[key] !== records[index - 1][key]),
  )
  const inputs = motion.inputs.filter((row) =>
    motion.label.endsWith('zoom')
      ? row.type === 'wheel'
      : row.type === 'pointermove' && row.buttons === 1,
  )
  const delivered = inputs
    .map((row) => row.delivered_ms)
    .filter((value) => typeof value === 'number')
  const responses = delivered
    .map((time) => changes.find((row) => row.at_ms >= time)?.at_ms - time)
    .filter((value) => Number.isFinite(value))
  return {
    delivered_input_count: delivered.length,
    inputs_without_later_camera_sample: delivered.length - responses.length,
    delivered_input_intervals: summarize(
      delivered.slice(1).map((time, index) => time - delivered[index]),
    ),
    input_to_next_camera_sample: summarize(responses),
    camera_change_intervals: summarize(
      changes.slice(1).map((row, index) => row.at_ms - changes[index].at_ms),
    ),
    ...summarize(records.map((row) => row.interval_ms)),
    average_raf_hz: ((records.length - 1) * 1000) / (records.at(-1).at_ms - records[0].at_ms),
    frames_with_camera_change: records.filter(
      (row, index) =>
        index && ['x', 'y', 'scale'].some((key) => row[key] !== records[index - 1][key]),
    ).length,
    intervals_over_25_ms: issues,
    intervals_over_50_ms: issues.filter((row) => row.interval_ms > 50),
  }
}
module.exports = { installMain, installFrame, startMotion, stopMotion, summarize, motionSummary }
