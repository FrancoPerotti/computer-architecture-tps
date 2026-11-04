// Local visual review of the actual renderer; optional explicit debug fixture.
// This development helper is not part of the Electron distribution.
const http = require('node:http')
const fs = require('node:fs/promises')
const path = require('node:path')
const { spawn } = require('node:child_process')
const { randomUUID, randomBytes } = require('node:crypto')
const { once } = require('node:events')

const gui = path.resolve(__dirname, '..'),
  software = path.resolve(gui, '..')
const debugDemo = process.argv.includes('--debug-demo')
if (process.argv.slice(2).some((arg) => arg !== '--debug-demo'))
  throw Error('Opción de preview desconocida.')
const port = Number(process.env.VIEWRV_PREVIEW_PORT || (debugDemo ? 5175 : 5174))
if (!Number.isInteger(port) || port < 1024 || port > 65535)
  throw Error('Puerto de preview inválido.')
const origin = `http://127.0.0.1:${port}`
const policy =
  "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' data: blob:; worker-src 'self' blob:; frame-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'"
const viewerPolicy =
  "default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'"
const types = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.ttf': 'font/ttf',
  '.svg': 'image/svg+xml',
}
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

function bridge(connection, registration) {
  return `(() => {
    const connection = ${JSON.stringify(connection)}, registration = ${JSON.stringify(registration)};
    let zoom = 1;
    const nativeOnly = () => { alert('Esta acción usa un diálogo o control de la aplicación de escritorio. En esta vista podés crear programas, abrir ejemplos, editar y ensamblar.'); return null; };
    window.viewrvDesktop = {
      previewDemo: ${debugDemo ? JSON.stringify({ scenario: 'addition' }) : 'undefined'},
      getCoreConnection: async () => connection,
      getRegistrationId: async () => registration,
      editCommand: async (command, text) => { if(command === 'paste') return navigator.clipboard.readText(); await navigator.clipboard.writeText(text || ''); return null; },
      windowControl: async () => nativeOnly(),
      chooseProgramFile: async () => nativeOnly(),
      chooseSavePath: async () => nativeOnly(),
      openExternal: async url => { if(!/^https?:\\/\\//.test(url)) throw Error('URL no admitida'); window.open(url, '_blank', 'noopener,noreferrer'); },
      getZoomFactor: async () => zoom,
      setZoomFactor: async factor => { if(!Number.isFinite(factor) || factor < .5 || factor > 2) throw Error('Escala inválida'); zoom = factor; document.documentElement.style.zoom = String(factor); document.body.style.width = 'calc(100vw / ' + factor + ')'; document.body.style.height = 'calc(100vh / ' + factor + ')'; },
      requestWindowClose: async () => nativeOnly(),
      onCloseRequested: () => () => {},
      finishWindowClose: async () => nativeOnly()
    };
    document.title = ${JSON.stringify(debugDemo ? 'viewrv · Demo visual de depuración · Sin FPGA' : 'viewrv · Vista previa visual')};
  })();`
}

;(async () => {
  await fs.access(path.join(gui, 'out/renderer/index.html'))
  const profile = await fs.mkdtemp(
    path.join(software, debugDemo ? 'build/browser-debug-demo-' : 'build/browser-preview-'),
  )
  await fs.chmod(profile, 0o700)
  const env = {
    ...process.env,
    PYTHONPATH: path.dirname(software),
    XDG_RUNTIME_DIR: profile,
    XDG_STATE_HOME: path.join(profile, 'state'),
    XDG_DATA_HOME: path.join(profile, 'data'),
    XDG_CONFIG_HOME: path.join(profile, 'config'),
    LOCALAPPDATA: path.join(profile, 'local'),
  }
  if (debugDemo) {
    env.VIEWRV_TEST_CONTROL = profile
    env.VIEWRV_EDUCATIONAL_TRACE = 'addition'
  }
  const python = path.join(
    software,
    '.venv',
    process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python',
  )
  const core = spawn(
    python,
    debugDemo
      ? ['-m', 'software.tests.viewrv.educational_core']
      : ['-m', 'software.viewrv.core', '--resources', path.join(software, 'resources')],
    { cwd: path.dirname(software), env, stdio: ['ignore', 'ignore', 'inherit'] },
  )
  let spawnError,
    workId = null,
    stopping = false
  core.on('error', (error) => {
    spawnError = error
  })
  const discoveryPath = path.join(
    profile,
    process.platform === 'win32' ? 'local/viewrv/runtime/core.json' : 'viewrv/core.json',
  )
  let discovery
  for (let attempt = 0; attempt < 300; attempt++) {
    if (spawnError) throw spawnError
    if (core.exitCode !== null || core.signalCode !== null)
      throw Error('El core de preview terminó antes de publicar su conexión.')
    try {
      discovery = JSON.parse(await fs.readFile(discoveryPath, 'utf8'))
      break
    } catch {}
    await wait(50)
  }
  if (!discovery) {
    core.kill('SIGTERM')
    throw Error('El core de preview no publicó su conexión.')
  }
  const target = new URL(discovery.base_url)
  if (target.hostname !== '127.0.0.1') {
    core.kill('SIGTERM')
    throw Error('La conexión de preview debe ser local.')
  }
  const token = randomBytes(32).toString('base64url'),
    registration = randomUUID()
  if (debugDemo) {
    async function call(route, body, owner) {
      const response = await fetch(new URL('/api/v1/' + route, target), {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${discovery.access_token}`,
          'Content-Type': 'application/json',
          ...(owner ? { 'X-Viewrv-Work-Id': owner } : {}),
        },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(30000),
      })
      const envelope = await response.json()
      if (!response.ok || envelope.error)
        throw Error(envelope.error?.message || 'No se pudo preparar la demo.')
      return envelope.result
    }
    try {
      workId = (await call('work/register', { client_type: 'gui', registration_id: registration }))
        .work_id
      await call('board/prepare', {}, workId)
      const program = await call('program/open-example', { example_id: 'addition' }, workId)
      const capture = {
        program_id: program.program_id,
        source_version: program.source_version,
        source_text: program.source_text,
      }
      await call('program/assemble', capture, workId)
      await call('program/load', capture, workId)
      await call(
        'debug/start',
        { program_id: program.program_id, source_version: program.source_version },
        workId,
      )
      for (let cycle = 0; cycle < 4; cycle++) await call('debug/step', {}, workId)
    } catch (error) {
      core.kill('SIGTERM')
      throw error
    }
  }

  const clientConnection = { ...discovery, base_url: origin, access_token: token }
  const script = bridge(clientConnection, registration)
  const server = http.createServer(async (req, res) => {
    try {
      if (req.headers.host !== `127.0.0.1:${port}`) {
        res.writeHead(403).end()
        return
      }
      res.setHeader('Cache-Control', 'no-store')
      res.setHeader('X-Content-Type-Options', 'nosniff')
      res.setHeader('Cross-Origin-Resource-Policy', 'same-origin')
      const url = new URL(req.url, origin)
      if (url.pathname.startsWith('/api/v1/')) {
        if (
          req.headers.authorization !== `Bearer ${token}` ||
          (req.headers.origin && req.headers.origin !== origin)
        ) {
          res.writeHead(403).end()
          return
        }
        const headers = {
          Authorization: `Bearer ${discovery.access_token}`,
          Origin: 'viewrv://app',
        }
        for (const name of ['content-type', 'content-length', 'x-viewrv-work-id'])
          if (req.headers[name]) headers[name] = req.headers[name]
        const upstream = http.request(
          new URL(url.pathname + url.search, target),
          { method: req.method, headers },
          (response) => {
            res.writeHead(response.statusCode, {
              'Content-Type': response.headers['content-type'] || 'application/json',
            })
            const registrationResponse = url.pathname === '/api/v1/work/register'
            let received = ''
            response.on('data', (chunk) => {
              if (registrationResponse) received += chunk
            })
            response.on('end', () => {
              if (registrationResponse) {
                try {
                  workId = JSON.parse(received).result.work_id
                } catch {}
              }
            })
            response.pipe(res)
          },
        )
        upstream.on('error', () => {
          if (!res.headersSent) res.writeHead(502)
          res.end()
        })
        res.on('close', () => upstream.destroy())
        req.pipe(upstream)
        return
      }
      if (!['GET', 'HEAD'].includes(req.method)) {
        res.writeHead(405).end()
        return
      }
      if (url.pathname === '/__preview_bridge.js') {
        if (req.headers['sec-fetch-site'] === 'cross-site') {
          res.writeHead(403).end()
          return
        }
        res
          .writeHead(200, { 'Content-Type': 'text/javascript' })
          .end(req.method === 'HEAD' ? undefined : script)
        return
      }
      const resource = url.pathname.startsWith('/content/')
      const root = resource ? path.join(software, 'resources') : path.join(gui, 'out/renderer')
      const file = path.resolve(
        root,
        '.' + decodeURIComponent(url.pathname === '/' ? '/index.html' : url.pathname),
      )
      if (!file.startsWith(root + path.sep)) {
        res.writeHead(404).end()
        return
      }
      const extension = path.extname(file)
      let body = await fs.readFile(file)
      if (['.html', '.js', '.css'].includes(extension)) {
        let text = body.toString('utf8').replaceAll('viewrv://app', origin)
        if (!resource && extension === '.html')
          text = text.replace('</head>', '<script src="/__preview_bridge.js"></script></head>')
        body = Buffer.from(text)
      }
      res.writeHead(200, {
        'Content-Type': types[extension] || 'application/octet-stream',
        'Content-Security-Policy': /^\/content\/viewer\/(index|explore|session)\.html$/.test(
          url.pathname,
        )
          ? viewerPolicy
          : policy,
      })
      res.end(req.method === 'HEAD' ? undefined : body)
    } catch {
      if (!res.headersSent) res.writeHead(404)
      res.end()
    }
  })
  async function stop() {
    if (stopping) return
    stopping = true
    if (workId && core.exitCode === null && core.signalCode === null) {
      try {
        const response = await fetch(new URL('/api/v1/work/finish', target), {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${discovery.access_token}`,
            'Content-Type': 'application/json',
            'X-Viewrv-Work-Id': workId,
          },
          body: '{}',
          signal: AbortSignal.timeout(15000),
        })
        if (!response.ok) throw Error('No se pudo conservar el trabajo de preview.')
      } catch (error) {
        console.error(error.message + ' Perfil conservado: ' + profile)
        stopping = false
        return
      }
    }
    server.close()
    server.closeAllConnections()
    if (core.exitCode === null && core.signalCode === null) {
      const exited = once(core, 'exit')
      core.kill('SIGTERM')
      await exited
    }
  }
  process.on('SIGINT', () => {
    void stop()
  })
  process.on('SIGTERM', () => {
    void stop()
  })
  server.on('error', (error) => {
    console.error(error.message)
    core.kill('SIGTERM')
    process.exitCode = 1
  })
  server.listen(port, '127.0.0.1', () => {
    console.log(`Vista previa: ${origin}`)
    console.log(`Perfil separado: ${profile}`)
    if (debugDemo)
      console.log(
        'DEMO VISUAL SIN FPGA: siete capturas predefinidas de Sumar dos números; no ejecuta Assembly arbitrario.',
      )
  })
})().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
})
