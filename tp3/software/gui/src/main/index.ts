import {
  app,
  BrowserWindow,
  clipboard,
  dialog,
  ipcMain,
  Menu,
  protocol,
  session,
  shell,
} from 'electron'
import { readFile } from 'node:fs/promises'
import { resolve, sep, extname } from 'node:path'
import { randomUUID } from 'node:crypto'
import { connectCore } from './bootstrap'

protocol.registerSchemesAsPrivileged([
  {
    scheme: 'viewrv',
    privileges: {
      standard: true,
      secure: true,
      supportFetchAPI: true,
      corsEnabled: true,
      stream: true,
    },
  },
])
const resources = app.isPackaged ? process.resourcesPath : resolve(__dirname, '../../../resources')
let window: BrowserWindow
let closing = false
const registrationId = randomUUID()
const devOrigin = process.env.ELECTRON_RENDERER_URL
  ? new URL(process.env.ELECTRON_RENDERER_URL).origin
  : undefined
const trustedURL = (url: string) => {
  try {
    const u = new URL(url)
    return u.origin === devOrigin || (u.protocol === 'viewrv:' && u.host === 'app')
  } catch {
    return false
  }
}
function handle(channel: string, callback: (...args: unknown[]) => unknown): void {
  ipcMain.handle(channel, (event, ...args: unknown[]) => {
    if (
      event.sender !== window.webContents ||
      event.senderFrame !== window.webContents.mainFrame ||
      !trustedURL(event.senderFrame.url)
    )
      throw new Error('Emisor IPC no admitido')
    return callback(...args)
  })
}
const csp =
  "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; font-src 'self' data:; img-src 'self' data: blob:; worker-src 'self' blob:; frame-src 'self'; connect-src 'self' http://127.0.0.1:*; object-src 'none'; base-uri 'none'"

app.whenReady().then(async () => {
  Menu.setApplicationMenu(null)
  await session.defaultSession.setProxy({ mode: 'direct' })
  session.defaultSession.setPermissionRequestHandler((_contents, _permission, callback) =>
    callback(false),
  )
  protocol.handle('viewrv', async (request) => {
    const url = new URL(request.url)
    if (url.host !== 'app') return new Response(null, { status: 404 })
    const root = url.pathname.startsWith('/content/')
      ? resources
      : resolve(__dirname, '../renderer')
    const path = url.pathname.startsWith('/content/')
      ? url.pathname
      : url.pathname === '/'
        ? '/index.html'
        : url.pathname
    const file = resolve(root, `.${decodeURIComponent(path)}`)
    if (!file.startsWith(`${root}${sep}`)) return new Response(null, { status: 404 })
    try {
      const types: Record<string, string> = {
        '.html': 'text/html',
        '.js': 'text/javascript',
        '.css': 'text/css',
        '.json': 'application/json',
        '.ttf': 'font/ttf',
        '.svg': 'image/svg+xml',
      }
      const policy = /^\/content\/viewer\/(index|explore|session)\.html$/.test(path)
        ? "default-src 'none'; script-src 'unsafe-inline' 'unsafe-eval'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:; connect-src 'none'; object-src 'none'; base-uri 'none'"
        : csp
      return new Response(new Uint8Array(await readFile(file)), {
        headers: {
          'Content-Type': types[extname(file)] || 'application/octet-stream',
          'Content-Security-Policy': policy,
        },
      })
    } catch {
      return new Response(null, { status: 404 })
    }
  })
  window = new BrowserWindow({
    width: 1440,
    height: 960,
    minWidth: 900,
    minHeight: 600,
    frame: false,
    title: 'viewrv',
    backgroundColor: '#f0f2f5',
    webPreferences: {
      preload: resolve(__dirname, '../preload/index.js'),
      contextIsolation: true,
      sandbox: true,
      nodeIntegration: false,
      webSecurity: true,
    },
  })
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//.test(url)) void shell.openExternal(url)
    return { action: 'deny' }
  })
  window.webContents.on('will-navigate', (event, url) => {
    if (!trustedURL(url)) event.preventDefault()
  })
  handle('viewrv:connection', async () => {
    const connection = await connectCore(resources, app.isPackaged, devOrigin)
    return connection
  })
  handle('viewrv:registration', () => registrationId)
  handle('viewrv:edit', async (command, text) => {
    if (command === 'paste') return clipboard.readText()
    if ((command === 'cut' || command === 'copy') && typeof text === 'string') {
      await clipboard.writeText(text)
      return null
    }
    throw new Error('Comando de edición inválido')
  })
  handle('viewrv:window', (action) => {
    if (action === 'minimize') window.minimize()
    else if (action === 'maximize') {
      if (window.isMaximized()) window.unmaximize()
      else window.maximize()
    } else throw new Error('Control de ventana inválido')
  })
  handle('viewrv:zoom:get', () => window.webContents.getZoomFactor())
  handle('viewrv:zoom:set', (factor) => {
    if (typeof factor !== 'number' || !Number.isFinite(factor) || factor < 0.5 || factor > 2)
      throw new Error('Escala inválida')
    window.webContents.setZoomFactor(factor)
  })
  handle('viewrv:file:open', async () => {
    const result = await dialog.showOpenDialog(window, {
      properties: ['openFile'],
      filters: [{ name: 'Assembly', extensions: ['s', 'asm'] }],
    })
    return result.canceled ? null : result.filePaths[0]
  })
  handle('viewrv:file:save', async (name) => {
    if (name !== undefined && (typeof name !== 'string' || name.length > 255 || /[/\\]/.test(name)))
      throw new Error('Nombre inválido')
    const result = await dialog.showSaveDialog(window, { defaultPath: name as string | undefined })
    return result.canceled ? null : result.filePath
  })
  handle('viewrv:licenses', async () => {
    const directory = app.isPackaged
      ? resolve(resources, 'licenses')
      : resolve(resources, '../build/licenses')
    const result = await shell.openPath(resolve(directory, 'index.html'))
    if (result) throw new Error(result)
  })
  handle('viewrv:external', (url) => {
    if (typeof url !== 'string' || !/^https?:\/\//.test(url)) throw new Error('URL no admitida')
    return shell.openExternal(url)
  })
  handle('viewrv:close:request', () => window.close())
  handle('viewrv:close:finish', () => {
    closing = true
    window.close()
  })
  window.on('close', (event) => {
    if (!closing) {
      event.preventDefault()
      window.webContents.send('viewrv:close:requested')
    }
  })
  if (devOrigin) await window.loadURL(process.env.ELECTRON_RENDERER_URL!)
  else await window.loadURL('viewrv://app/')
})
app.on('window-all-closed', () => app.quit())
