import { readFile } from 'node:fs/promises'
import { resolve, isAbsolute } from 'node:path'
import { homedir } from 'node:os'
import { request } from 'node:http'
import { spawn, type ChildProcess } from 'node:child_process'
import {
  CoreConnection,
  ProcessorProfile,
  validateConnection,
  validateEnvelope,
} from '../shared/contracts'

const delay = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms))
function xdg(name: string, fallback: string): string {
  const value = process.env[name]
  return value && isAbsolute(value) ? value : resolve(homedir(), fallback)
}
export async function discoveryPath(): Promise<string> {
  if (process.platform === 'win32') {
    if (!process.env.LOCALAPPDATA) throw new Error('CORE_DISCOVERY_FAILED')
    return resolve(process.env.LOCALAPPDATA, 'viewrv/runtime/core.json')
  }
  const runtime = process.env.XDG_RUNTIME_DIR
  if (runtime && isAbsolute(runtime)) {
    const { access, constants } = await import('node:fs/promises')
    try {
      await access(runtime, constants.W_OK)
      return resolve(runtime, 'viewrv/core.json')
    } catch {
      /* state fallback */
    }
  }
  return resolve(xdg('XDG_STATE_HOME', '.local/state'), 'viewrv/runtime/core.json')
}
// node:http connects directly and never follows redirects or environment proxies.
export function getInfo(connection: CoreConnection): Promise<Record<string, unknown>> {
  return new Promise((accept, reject) => {
    const req = request(
      `${connection.base_url}/api/v1/core/info`,
      { headers: { Authorization: `Bearer ${connection.access_token}` }, timeout: 3000 },
      (res) => {
        if (res.statusCode !== 200) {
          res.resume()
          reject(new Error(res.statusCode === 401 ? 'AUTHENTICATION_FAILED' : 'CORE_UNAVAILABLE'))
          return
        }
        const chunks: Buffer[] = []
        let size = 0
        res.on('data', (chunk) => {
          size += chunk.length
          if (size > 1024 * 1024) {
            req.destroy(new Error('CORE_UNAVAILABLE'))
            return
          }
          chunks.push(chunk)
        })
        res.on('end', () => {
          try {
            accept(
              validateEnvelope<Record<string, unknown>>(
                JSON.parse(Buffer.concat(chunks).toString()),
              ).result!,
            )
          } catch (error) {
            reject(error)
          }
        })
        res.on('error', reject)
      },
    )
    req.on('timeout', () => req.destroy(new Error('CORE_UNAVAILABLE')))
    req.on('error', reject)
    req.end()
  })
}
export async function connectCore(
  resources: string,
  packaged: boolean,
  devOrigin?: string,
): Promise<CoreConnection> {
  const profile = JSON.parse(
    await readFile(resolve(resources, 'content/processor_profile.json'), 'utf8'),
  ) as ProcessorProfile
  const file = await discoveryPath()
  const deadline = Date.now() + 15000
  let candidate: ChildProcess | undefined
  let started = false
  let spawnError = false
  let sawDiscovery = false
  while (Date.now() < deadline) {
    try {
      let raw: string
      try {
        raw = await readFile(file, 'utf8')
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ENOENT')
          throw new Error('CORE_DISCOVERY_FAILED')
        if (sawDiscovery && candidate?.exitCode === 0) {
          started = false
          candidate = undefined
          sawDiscovery = false
        }
        throw new Error('CORE_UNAVAILABLE')
      }
      let parsed: unknown
      try {
        parsed = JSON.parse(raw)
      } catch {
        throw new Error('CORE_DISCOVERY_FAILED')
      }
      const connection = validateConnection(parsed)
      sawDiscovery = true
      const info = await getInfo(connection)
      if (info.instance_id !== connection.instance_id) throw new Error('CORE_IDENTITY_MISMATCH')
      const remote = info.processor_profile as ProcessorProfile
      if (
        info.api_version !== 1 ||
        !remote ||
        ['profile_id', 'revision', 'memory_profile'].some(
          (key) => remote[key as keyof ProcessorProfile] !== profile[key as keyof ProcessorProfile],
        )
      )
        throw new Error('CORE_INCOMPATIBLE')
      return connection
    } catch (error) {
      if (
        [
          'CORE_IDENTITY_MISMATCH',
          'CORE_INCOMPATIBLE',
          'CORE_DISCOVERY_FAILED',
          'AUTHENTICATION_FAILED',
        ].includes((error as Error).message)
      )
        throw error
    }
    if (!started) {
      const root = resolve(resources, '..')
      const executable = packaged
        ? resolve(
            resources,
            'core',
            process.platform === 'win32' ? 'viewrv-core.exe' : 'viewrv-core',
          )
        : resolve(root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python')
      const args = packaged ? [] : ['-m', 'software.viewrv.core']
      if (devOrigin) args.push('--dev-origin', devOrigin)
      candidate = spawn(executable, args, {
        cwd: packaged ? root : resolve(root, '..'),
        stdio: 'ignore',
        detached: true,
        windowsHide: true,
      })
      candidate.on('error', () => {
        spawnError = true
      })
      candidate.unref()
      started = true
    }
    if (
      spawnError ||
      (candidate?.exitCode !== null &&
        candidate?.exitCode !== undefined &&
        candidate.exitCode !== 0)
    )
      throw new Error('CORE_START_FAILED')
    await delay(50)
  }
  throw new Error('CORE_UNAVAILABLE')
}
