// Functional window checks run sequentially: they share the graphical host.
const { spawn } = require('node:child_process')
const { mkdirSync, writeFileSync, readFileSync, createWriteStream } = require('node:fs')
const { resolve } = require('node:path')
const gui = resolve(__dirname, '..')
const suites = [
  'smoke',
  'programs-smoke',
  'conservation-smoke',
  'preparation-smoke',
  'sessions-smoke',
  'ide-smoke',
  'drawing-smoke',
  'diagram-smoke',
  'graphical-smoke',
  'follow-loop-smoke',
  'examples-smoke',
  'editor-workspace-smoke',
  'processor-state-smoke',
  'source-follow-smoke',
  'breakpoint-visibility-smoke',
  'completion-smoke',
  'formatter-smoke',
  'instruction-resource-smoke',
  'stream-lifecycle-smoke',
]
const requested = process.argv.slice(2)
if (requested.some((name) => !suites.includes(name)))
  throw Error('Unknown GUI suite: ' + requested.filter((name) => !suites.includes(name)).join(', '))
const selected = requested.length ? [...new Set(requested)] : suites
const output = resolve(gui, '../build/gui-check', new Date().toISOString().replace(/[:.]/g, '-'))
mkdirSync(output, { recursive: true })
const version = (name) =>
  JSON.parse(readFileSync(resolve(gui, 'node_modules', name, 'package.json'), 'utf8')).version
writeFileSync(
  resolve(output, 'environment.json'),
  JSON.stringify(
    {
      node: process.version,
      platform: process.platform,
      arch: process.arch,
      electron: version('electron'),
      monaco: version('monaco-editor'),
      playwright: version('playwright'),
      python_requested: readFileSync(resolve(gui, '../.python-version'), 'utf8').trim(),
      external_playwright_override: !!process.env.PLAYWRIGHT_MODULE,
    },
    null,
    2,
  ) + '\n',
)
console.log('GUI evidence: ' + output)

async function verify(name) {
  const started = Date.now(),
    log = resolve(output, name + '.log')
  const file = createWriteStream(log)
  const child = spawn(process.execPath, [resolve(gui, 'tests', name + '.cjs')], {
    cwd: gui,
    env: process.env,
    detached: process.platform !== 'win32',
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  child.stdout.pipe(file, { end: false })
  child.stderr.pipe(file, { end: false })
  let timedOut = false
  const timer = setTimeout(() => {
    timedOut = true
    if (process.platform === 'win32') child.kill('SIGTERM')
    else process.kill(-child.pid, 'SIGTERM')
  }, 180000)
  const code = await new Promise((resolve) => {
    child.once('error', (error) => {
      file.write(String(error))
      resolve(1)
    })
    child.once('close', (code) => resolve(code ?? 1))
  })
  clearTimeout(timer)
  await new Promise((resolve) => file.end(resolve))
  const result = { name, code, timedOut, duration_ms: Date.now() - started, log }
  console.log(`${code === 0 ? 'PASS' : 'FAIL'} ${name} (${Math.round(result.duration_ms / 1000)}s)`)
  return result
}
;(async () => {
  const results = []
  for (const name of selected) results.push(await verify(name))
  writeFileSync(resolve(output, 'summary.json'), JSON.stringify(results, null, 2) + '\n')
  const failed = results.filter((result) => result.code !== 0)
  console.log(`${results.length - failed.length}/${results.length} GUI checks passed`)
  if (failed.length) {
    console.error('Failed: ' + failed.map((result) => result.name).join(', '))
    process.exitCode = 1
  }
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
