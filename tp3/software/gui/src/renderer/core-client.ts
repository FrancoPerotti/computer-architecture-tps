import { fetchEventSource } from '@microsoft/fetch-event-source'
import { create } from 'zustand'
import { ApiError, CoreConnection, StateEvent, validateEnvelope } from '../shared/contracts'
import { AppliedState, applyEvent, emptyState } from './live-state'

interface Presentation {
  live: AppliedState
  synchronized: boolean
  problem: string | null
  closing: boolean
  closeProblem: CoreFailure | null
  freshImage: boolean
}
export const useCore = create<Presentation>(() => ({
  live: emptyState,
  synchronized: false,
  problem: null,
  closing: false,
  closeProblem: null,
  freshImage: false,
}))
let connection: CoreConnection | null = null
let workId: string | null = null
export function ownWorkId(): string | null {
  return workId
}
let stopped = false
let streamController: AbortController | null = null
const lifetime = new AbortController()
let ready: Promise<void>
let registrationAttempted = false

export class CoreFailure extends Error {
  constructor(public readonly error: ApiError) {
    super(error.message)
  }
}
let beforeClose: (() => Promise<void>) | null = null
let cancelClose: (() => void) | null = null
export function onBeforeClose(prepare: () => Promise<void>, cancel: () => void): void {
  beforeClose = prepare
  cancelClose = cancel
}
export async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  await ready
  return operation<T>(method, path, body)
}

async function operation<T>(method: string, path: string, body?: unknown): Promise<T> {
  if (!connection) throw new Error('CORE_UNAVAILABLE')
  const response = await fetch(`${connection.base_url}/api/v1/${path}`, {
    method,
    redirect: 'error',
    credentials: 'omit',
    cache: 'no-store',
    signal: method === 'GET' ? AbortSignal.timeout(15000) : undefined,
    headers: {
      Authorization: `Bearer ${connection.access_token}`,
      'Content-Type': 'application/json',
      ...(workId ? { 'X-Viewrv-Work-Id': workId } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  })
  const envelope = validateEnvelope<T>(await response.json())
  if (envelope.error) throw new CoreFailure(envelope.error)
  if (!response.ok) throw new Error('REQUEST_RESULT_UNCONFIRMED')
  return envelope.result!
}
async function initialize(): Promise<void> {
  const next = await window.viewrvDesktop.getCoreConnection()
  if (connection?.instance_id !== next.instance_id) {
    workId = null
    useCore.setState({ live: emptyState, synchronized: false, freshImage: false })
  }
  connection = next
  const registrationId = await window.viewrvDesktop.getRegistrationId()
  registrationAttempted = true
  try {
    const registered = await operation<{ work_id: string }>('POST', 'work/register', {
      client_type: 'gui',
      registration_id: registrationId,
    })
    workId = registered.work_id
  } catch (error) {
    if (
      error instanceof CoreFailure &&
      ['AUTHENTICATION_FAILED', 'INVALID_REQUEST', 'CORE_SHUTTING_DOWN'].includes(error.error.code)
    )
      registrationAttempted = false
    throw error
  }
}
function wait(ms: number): Promise<void> {
  return new Promise((resolve) => {
    if (lifetime.signal.aborted) {
      resolve()
      return
    }
    const timer = setTimeout(done, ms)
    function done() {
      clearTimeout(timer)
      lifetime.signal.removeEventListener('abort', done)
      resolve()
    }
    lifetime.signal.addEventListener('abort', done, { once: true })
  })
}
async function observe(): Promise<void> {
  const delays = [1000, 2000, 4000, 8000, 10000]
  let attempt = 0
  while (!stopped) {
    let watchdog: ReturnType<typeof setInterval> | undefined
    try {
      ready = initialize()
      await ready
      if (stopped) break
      const active = connection!
      streamController = new AbortController()
      let activity = Date.now()
      let tick = activity
      watchdog = setInterval(() => {
        const now = Date.now()
        if (now - activity >= 45000 || now - tick >= 45000) streamController?.abort()
        tick = now
      }, 1000)
      let initial = false
      await fetchEventSource(`${active.base_url}/api/v1/events`, {
        headers: { Authorization: `Bearer ${active.access_token}`, 'X-Viewrv-Work-Id': workId! },
        signal: streamController.signal,
        openWhenHidden: true,
        async fetch(input, init) {
          const response = await fetch(input, {
            ...init,
            redirect: 'error',
            credentials: 'omit',
            cache: 'no-store',
          })
          if (!response.body) return response
          const reader = response.body.getReader()
          const body = new ReadableStream({
            async pull(controller) {
              try {
                const chunk = await reader.read()
                if (chunk.done) {
                  controller.close()
                  reader.releaseLock()
                } else {
                  activity = Date.now()
                  controller.enqueue(chunk.value)
                }
              } catch (error) {
                controller.error(error)
              }
            },
            cancel(reason) {
              return reader.cancel(reason)
            },
          })
          return new Response(body, { status: response.status, headers: response.headers })
        },
        async onopen(response) {
          if (
            !response.ok ||
            !response.headers.get('content-type')?.startsWith('text/event-stream')
          )
            throw new Error('EVENT_STREAM_INTERRUPTED')
        },
        onmessage(message) {
          if (!message.data) return
          const event = JSON.parse(message.data) as StateEvent
          if (!initial && event.type !== 'state') throw new Error('EVENT_STREAM_INTERRUPTED')
          const live = applyEvent(useCore.getState().live, event, active.instance_id)
          initial = true
          if (!initialZoomApplied && live.state) {
            initialZoomApplied = true
            void window.viewrvDesktop.setZoomFactor(live.state.preferences.ui_zoom)
          }
          let freshImage = useCore.getState().freshImage
          if (event.type === 'state')
            freshImage =
              live.state?.loaded_image.status === 'loaded' &&
              !live.state.sessions.some(
                (session) =>
                  session.program_id === live.state?.loaded_image.program_id &&
                  session.source_version === live.state.loaded_image.source_version,
              )
          else {
            if (event.data.loaded_image) freshImage = event.data.loaded_image.status === 'loaded'
            if (
              event.data.sessions?.some(
                (session) =>
                  session.debug_open ||
                  (session.mode === 'run' && session.execution_status === 'ongoing'),
              )
            )
              freshImage = false
          }
          useCore.setState({ live, synchronized: true, problem: null, freshImage })
          attempt = 0
        },
        onclose() {
          throw new Error('EVENT_STREAM_INTERRUPTED')
        },
        onerror(error) {
          throw error
        },
      })
    } catch (error) {
      if (!stopped) useCore.setState({ synchronized: false, problem: (error as Error).message })
    } finally {
      if (watchdog) clearInterval(watchdog)
    }
    if (!stopped) {
      useCore.setState({ synchronized: false })
      await wait(delays[Math.min(attempt++, delays.length - 1)])
    }
  }
}
let closing = false
let initialZoomApplied = false
export function startCore(): void {
  ready = initialize()
  ready
    .then(() => {
      if (!stopped) void observe()
    })
    .catch((error) => {
      useCore.setState({ problem: (error as Error).message })
      if (!stopped) void observe()
    })
  window.viewrvDesktop.onCloseRequested(() => {
    void finish()
  })
}
export async function finish(discard = false): Promise<void> {
  if (closing) return
  closing = true
  useCore.setState({ closing: true, closeProblem: null })
  try {
    try {
      await ready
    } catch (error) {
      if (registrationAttempted) await initialize()
    }
    if (beforeClose && !discard) await beforeClose()
    if (workId && connection) await operation('POST', 'work/finish', { discard_unsaved: discard })
    stopped = true
    lifetime.abort()
    streamController?.abort()
    await window.viewrvDesktop.finishWindowClose()
  } catch (error) {
    closing = false
    const failure =
      error instanceof CoreFailure
        ? error
        : new CoreFailure({ code: 'REQUEST_RESULT_UNCONFIRMED', message: (error as Error).message })
    useCore.setState({ problem: failure.message, closeProblem: failure })
  }
}
export function cancelWindowClose(): void {
  closing = false
  cancelClose?.()
  useCore.setState({ closing: false, closeProblem: null })
}
