import type {
  AssemblyView,
  ImageReference,
  LiveState,
  SessionView,
  SourceCapture,
} from '../shared/contracts'
import type { DocumentSync } from './document-sync'

export type ProcessorAction = 'assemble' | 'load' | 'run' | 'debug' | 'combined'
export interface ActionContext {
  state: LiveState | null
  synchronized: boolean
  closing: boolean
  workId: string | null
  capture: SourceCapture | null
  busy: boolean
  freshImage?: boolean
}
export function selectedSession(
  state: LiveState | null,
  workId: string | null,
): SessionView | null {
  if (!state) return null
  const controller = state.works.find((work) => work.owns_board)
  const work = controller ?? state.works.find((work) => work.work_id === workId)
  return state.sessions.find((session) => session.session_id === work?.session_id) ?? null
}
/** Explanations are also rendered as tooltips on unavailable controls. The core remains authoritative. */
export function actionReason(action: ProcessorAction, context: ActionContext): string | null {
  const { state, capture, workId } = context
  if (context.closing) return 'Resolviendo el cierre de la aplicación'
  if (!context.synchronized || !state) return 'Esperá a que se restablezca la conexión con el core'
  if (!capture) return 'Seleccioná un programa'
  if (action === 'assemble') return context.busy ? 'Hay una acción en curso' : null
  if (state.works.some((work) => work.owns_board && work.work_id !== workId))
    return 'La placa está controlada por otro trabajo'
  if (
    context.busy ||
    state.works.some((work) =>
      work.pending_commands.some((command) =>
        /^(program load|run start|debug (step|continue|restart))$/.test(command),
      ),
    )
  )
    return 'Hay una operación del procesador en curso'
  if (selectedSession(state, workId)?.debug_open) return 'Primero detené la depuración'
  if (state.board.connection_status !== 'checked' || state.board.recovery_pending)
    return 'Conectá la FPGA y comprobá la comunicación'
  if (action === 'combined') return null
  if (action === 'load') {
    const assembly = state.assemblies.find((entry) => entry.program_id === capture.program_id)
    return assembly?.status === 'ready' && assembly.source_version === capture.source_version
      ? null
      : 'Ensamblá la versión actual antes de cargar'
  }
  if (
    state.loaded_image.status !== 'loaded' ||
    state.loaded_image.program_id !== capture.program_id
  )
    return 'Este programa no está cargado en la FPGA'
  if (state.loaded_image.source_version !== capture.source_version)
    return 'El programa fue modificado desde la última carga'
  if (context.freshImage === false)
    return 'Volvé a cargar el programa para empezar una nueva ejecución'
  return null
}
export type ApiCall = <T>(path: string, body: unknown) => Promise<T>
export interface WorkflowEvents {
  progress(message: string): void
  assembled(result: AssemblyView, capture: SourceCapture): void
  loaded(result: ImageReference): void
}
/** Capture once; edits before LOAD reject the chain, edits after admission never retarget RUN. */
export async function programWorkflow(
  document: DocumentSync,
  action: ProcessorAction,
  call: ApiCall,
  events: WorkflowEvents,
): Promise<unknown> {
  return document.action(async (capture) => {
    if (action === 'assemble' || action === 'combined') {
      events.progress('Ensamblando…')
      const result = await call<AssemblyView>('program/assemble', capture)
      events.assembled(result, capture)
      if (action === 'assemble') return result
    }
    let reference: Pick<ImageReference, 'program_id' | 'source_version'> = {
      program_id: capture.program_id,
      source_version: capture.source_version,
    }
    if (action === 'load' || action === 'combined') {
      if (document.snapshot().capture.source_version !== capture.source_version)
        throw new Error(
          'El programa cambió antes de LOAD. Ensamblá la versión actual para continuar.',
        )
      events.progress('Cargando…')
      const loaded = await call<ImageReference>('program/load', capture)
      events.loaded(loaded)
      reference = { program_id: loaded.program_id, source_version: loaded.source_version }
      if (action === 'load') return loaded
    }
    events.progress(action === 'debug' ? 'Abriendo depuración…' : 'Ejecutando…')
    return call(action === 'debug' ? 'debug/start' : 'run/start', reference)
  })
}
export type NumberFormat = 'hex' | 'signed' | 'unsigned' | 'binary'
export function formatValue(
  value: number | string | boolean,
  bits: number,
  format: NumberFormat,
): string {
  const n = BigInt(typeof value === 'boolean' ? Number(value) : value)
  if (format === 'signed') return BigInt.asIntN(bits, n).toString()
  if (format === 'unsigned') return n.toString()
  if (format === 'binary') return '0b' + n.toString(2).padStart(bits, '0')
  return '0x' + n.toString(16).padStart(Math.ceil(bits / 4), '0')
}
