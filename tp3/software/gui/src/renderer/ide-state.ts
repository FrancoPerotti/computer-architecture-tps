import { create } from 'zustand'
import type { AssemblyView, SourceCapture } from '../shared/contracts'
import { CoreFailure, request } from './core-client'
import type { DocumentSync } from './document-sync'
import { programWorkflow, type ProcessorAction } from './ide-workflow'

export interface Toast {
  id: number
  kind: 'success' | 'error' | 'info'
  message: string
  details?: string
  action?: () => void
  actionLabel?: string
}
export interface ViewRequest {
  id: number
  component: 'debug' | 'diagram' | 'assembly' | 'catalog' | 'connection' | 'example-info'
  session_id?: string
  program_id?: string
  group_id?: string
  placement?: 'right'
  capture?: SourceCapture
  assembly?: AssemblyView
}
interface WorkspaceState {
  section: 'viewer' | 'editor' | 'settings'
  focus: string | null
  busy: ProcessorAction | null
  progress: string | null
  controlling: boolean
  view: ViewRequest | null
  toasts: Toast[]
  connectionOpen: boolean
  debugView: 'debug' | 'diagram'
}
export const useWorkspace = create<WorkspaceState>(() => ({
  section: 'viewer',
  focus: null,
  busy: null,
  progress: null,
  controlling: false,
  view: null,
  toasts: [],
  connectionOpen: false,
  debugView: 'debug',
}))
let nextId = 0
export const translations = new Map<string, { assembly: AssemblyView; capture: SourceCapture }>()
export function openView(view: Omit<ViewRequest, 'id'>, activate = true): void {
  if (view.component === 'connection') {
    useWorkspace.setState({ connectionOpen: true })
    return
  }
  useWorkspace.setState({
    ...(activate ? { section: 'editor' as const } : {}),
    view: { ...view, id: ++nextId },
  })
}
export function notify(
  kind: Toast['kind'],
  message: string,
  details?: string,
  action?: () => void,
  actionLabel?: string,
): void {
  const id = ++nextId
  useWorkspace.setState((state) => ({
    toasts: [...state.toasts.slice(-4), { id, kind, message, details, action, actionLabel }],
  }))
  if (kind !== 'error') setTimeout(() => dismissToast(id), 7000)
}
export function dismissToast(id: number): void {
  useWorkspace.setState((state) => ({ toasts: state.toasts.filter((toast) => toast.id !== id) }))
}
export function reportError(error: unknown): void {
  const failure = error instanceof CoreFailure ? error.error : null
  notify(
    'error',
    error instanceof Error ? error.message : String(error),
    failure
      ? `${failure.code}${failure.details ? '\n' + JSON.stringify(failure.details, null, 2) : ''}`
      : undefined,
  )
}
export async function launchProgram(
  document: DocumentSync,
  action: ProcessorAction,
  debugView: 'debug' | 'diagram' = 'debug',
): Promise<void> {
  if (useWorkspace.getState().busy) return
  useWorkspace.setState({ busy: action, progress: 'Confirmando revisión…' })
  try {
    const result = (await programWorkflow(
      document,
      action,
      (path, body) => request('POST', path, body),
      {
        progress: (progress) => useWorkspace.setState({ progress }),
        assembled: (assembly, capture) => {
          translations.set(capture.program_id, { assembly, capture })
          notify(
            'success',
            'Programa ensamblado',
            undefined,
            () => openView({ component: 'assembly', assembly, capture }),
            'Ver ensamblado',
          )
        },
        loaded: () => notify('success', 'Programa cargado en la FPGA'),
      },
    )) as { session_id?: string }
    if (result?.session_id) {
      const component = action === 'debug' ? debugView : 'debug'
      if (action === 'debug') useWorkspace.setState({ debugView })
      openView(
        {
          component,
          session_id: result.session_id,
          program_id: document.snapshot().program.program_id,
          placement: 'right',
        },
        false,
      )
    }
  } catch (error) {
    reportError(error)
  } finally {
    useWorkspace.setState({ busy: null, progress: null })
  }
}
export async function processorControl(
  action: 'step' | 'continue' | 'pause' | 'restart' | 'stop' | 'run-stop',
): Promise<void> {
  const long = action === 'step' || action === 'continue' || action === 'restart'
  if (useWorkspace.getState().controlling && long) return
  if (long) useWorkspace.setState({ controlling: true })
  try {
    const result = await request<{ session_id?: string }>(
      'POST',
      action === 'run-stop' ? 'run/stop' : `debug/${action}`,
      {},
    )
    if (action === 'restart' && result.session_id)
      openView(
        {
          component: useWorkspace.getState().debugView,
          session_id: result.session_id,
          placement: 'right',
        },
        false,
      )
  } catch (error) {
    reportError(error)
  } finally {
    if (long) useWorkspace.setState({ controlling: false })
  }
}
