// Start the local fixture preview outside the invoking terminal's process group.
const { spawn } = require('node:child_process')
const { openSync, closeSync } = require('node:fs')
const fs = require('node:fs/promises')
const path = require('node:path')
const build = path.resolve(__dirname, '../../build')
const port = Number(process.env.VIEWRV_PREVIEW_PORT || 5175)
if (!Number.isInteger(port) || port < 1024 || port > 65535)
  throw Error('Puerto de preview inválido.')
const origin = `http://127.0.0.1:${port}`
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function probe() {
  try {
    const response = await fetch(origin + '/__preview_bridge.js', {
      signal: AbortSignal.timeout(500),
    })
    return response.ok
      ? /previewDemo:\s*\{"scenario":"addition"\}/.test(await response.text())
        ? 'demo'
        : 'other'
      : 'other'
  } catch {
    return null
  }
}
;(async () => {
  const existing = await probe()
  if (existing === 'demo') {
    console.log('Demo disponible: ' + origin)
    return
  }
  if (existing) throw Error('El puerto está ocupado por otro servicio. Elegí VIEWRV_PREVIEW_PORT.')
  await fs.mkdir(build, { recursive: true })
  const logPath = path.join(build, `browser-debug-demo-${port}.log`),
    pidPath = path.join(build, `browser-debug-demo-${port}.pid`)
  const output = openSync(logPath, 'a', 0o600)
  const child = spawn(
    process.execPath,
    [path.join(__dirname, 'browser-preview.cjs'), '--debug-demo'],
    {
      cwd: path.resolve(__dirname, '..'),
      env: process.env,
      detached: true,
      stdio: ['ignore', output, output],
    },
  )
  closeSync(output)
  child.unref()
  let failure
  child.on('error', (error) => {
    failure = error
  })
  for (let attempt = 0; attempt < 80; attempt++) {
    if (failure) throw failure
    if (child.exitCode !== null || child.signalCode !== null)
      throw Error('No se pudo iniciar la demo. Revisá ' + logPath)
    if ((await probe()) === 'demo') {
      await fs.writeFile(pidPath, String(child.pid) + '\n', { mode: 0o600 })
      console.log('Demo en segundo plano: ' + origin)
      console.log('PID: ' + child.pid)
      console.log('Log: ' + logPath)
      return
    }
    await wait(250)
  }
  child.kill('SIGTERM')
  throw Error('La demo no quedó disponible. Revisá ' + logPath)
})().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
})
