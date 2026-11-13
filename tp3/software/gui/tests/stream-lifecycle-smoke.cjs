// TEST-PC-029: real SSE comments, client inactivity watchdog, reconnect and close.
const assert = require('node:assert/strict')
const { readFileSync, existsSync } = require('node:fs')
const { resolve } = require('node:path')
const { withGuiEnvironment, until } = require('./gui-fixture.cjs')
const { waitForCore } = require('./ui-commands.cjs')

withGuiEnvironment(
  'stream-lifecycle',
  async ({ root, launch }) => {
    const connection = JSON.parse(readFileSync(resolve(root, 'viewrv/core.json'), 'utf8'))
    async function api(path, body, owner) {
      const response = await fetch(connection.base_url + '/api/v1/' + path, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Authorization: 'Bearer ' + connection.access_token,
          'Content-Type': 'application/json',
          ...(owner ? { 'X-Viewrv-Work-Id': owner } : {}),
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      })
      const envelope = await response.json()
      assert.equal(envelope.error, null)
      return envelope.result
    }
    const cli = (await api('work/register', { client_type: 'cli' })).work_id
    const { instance, page, errors } = await launch()
    const mutations = []
    page.on('request', (request) => {
      if (request.method() === 'POST' && request.url().startsWith(connection.base_url + '/api/v1/'))
        mutations.push(new URL(request.url()).pathname)
    })
    await waitForCore(page)
    // Install the browser clock before reloading, so every renderer timer uses
    // it. The core and its real 15-second SSE comments keep wall-clock time.
    await page.clock.install()
    await page.clock.pauseAt(new Date(Date.now() + 1000))
    await page.addInitScript(() => {
      const audit = { requests: 0, aborts: 0, comments: 0, states: 0, updates: 0, works: [] }
      window.__sseAudit = audit
      const originalFetch = window.fetch.bind(window)
      window.fetch = async (input, options) => {
        if (!String(input?.url ?? input).endsWith('/api/v1/events'))
          return originalFetch(input, options)
        audit.requests++
        options?.signal?.addEventListener('abort', () => audit.aborts++, { once: true })
        const response = await originalFetch(input, options)
        let pending = ''
        const decoder = new TextDecoder()
        const transform = new TransformStream({
          transform(chunk, controller) {
            pending += decoder.decode(chunk, { stream: true })
            const lines = pending.split('\n')
            pending = lines.pop()
            for (const line of lines) {
              if (line.startsWith(':')) audit.comments++
              if (line.startsWith('data: ')) {
                const message = JSON.parse(line.slice(6))
                if (message.type === 'state') {
                  audit.states++
                  audit.works = message.data.works.map((work) => work.work_id)
                } else audit.updates++
              }
            }
            // Observe the actual bytes; do not synthesize or drop SSE frames.
            controller.enqueue(chunk)
          },
        })
        return new Response(response.body.pipeThrough(transform), {
          status: response.status,
          headers: response.headers,
        })
      }
    })
    await page.reload({ waitUntil: 'domcontentloaded' })
    try {
      await until(() => page.evaluate(() => window.__sseAudit?.states === 1))
    } catch (error) {
      console.error('SSE diagnostic:', await page.evaluate(() => window.__sseAudit))
      console.error('Renderer errors:', errors)
      console.error(await page.locator('body').innerText())
      throw error
    }
    const originalWorks = await page.evaluate(() => window.__sseAudit.works)
    const uart = resolve(root, 'uart.tx')
    const transmitted = () => (existsSync(uart) ? readFileSync(uart, 'utf8') : '')
    const before = transmitted()
    await page.clock.fastForward(40000)
    try {
      await until(() => page.evaluate(() => window.__sseAudit.comments > 0), 20000)
    } catch (error) {
      console.error('Keepalive diagnostic:', await page.evaluate(() => window.__sseAudit))
      throw error
    }
    await page.clock.fastForward(40000)
    const kept = await page.evaluate(() => window.__sseAudit)
    assert.equal(kept.requests, 1, 'A real comment did not preserve the stream')
    assert.equal(kept.aborts, 0)
    assert.equal(kept.updates, 0, 'The keepalive proof unexpectedly used a JSON update')
    await page.clock.fastForward(46000)
    await until(() => page.evaluate(() => window.__sseAudit.aborts === 1))
    // Allow the aborted fetch to settle before advancing its reconnect timer.
    for (let attempt = 0; attempt < 5; attempt++) {
      await page.clock.runFor(1100)
      if (await page.evaluate(() => window.__sseAudit.states >= 2)) break
      await new Promise((resolve) => setTimeout(resolve, 50))
    }
    await until(() => page.evaluate(() => window.__sseAudit.states === 2))
    assert.deepEqual(await page.evaluate(() => window.__sseAudit.works), originalWorks)
    assert.equal((await api('work/cli/status')).work_id, cli)
    assert.equal(transmitted(), before, 'Inactivity or reconnect generated UART traffic')
    // Closing during the next retry must cancel the wait and finish only GUI.
    await page.clock.fastForward(46000)
    await until(() => page.evaluate(() => window.__sseAudit.aborts === 2))
    const closed = page.waitForEvent('close')
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    assert.equal((await api('work/cli/status')).work_id, cli)
    assert.equal(transmitted(), before)
    assert.deepEqual(
      mutations.filter((path) => !['/api/v1/work/register', '/api/v1/work/finish'].includes(path)),
      [],
      'Observation lifecycle sent an unrelated mutating command',
    )
    assert.deepEqual(errors, [])
    await api('work/finish', {}, cli)
    await instance.close()
    console.log(
      'TEST-PC-029: real comment keepalive, 45s client inactivity, fresh state reconnect, unchanged work identities, no UART/reset and close during retry passed.',
    )
  },
  { coreModule: 'controlled_core' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
