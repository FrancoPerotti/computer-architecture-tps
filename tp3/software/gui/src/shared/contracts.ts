export interface ProcessorProfile {
  profile_id: string
  revision: number
  memory_profile: 'REFERENCE' | 'ALT_1000'
}
export interface CoreConnection {
  base_url: string
  instance_id: string
  api_version: number
  access_token: string
}
export interface Work {
  work_id: string
  client_type: 'gui' | 'cli'
  pending_commands: string[]
  owns_board: boolean
  session_id: string | null
  debug_open: boolean
}
export interface Board {
  connection_status: 'closed' | 'checking' | 'checked' | 'unreliable'
  port: string | null
  controller: 'gui' | 'cli' | null
  preparation_required: boolean
  recovery_pending: boolean
}
export interface Preferences {
  schema_version: number
  default_author: string | null
  record_by_default: boolean
  last_serial_port: string | null
  ui_zoom: number
  language: string
}
export interface SourceCapture {
  program_id: string
  source_version: string
  source_text: string
}
export interface ProgramView extends SourceCapture {
  source_path: string | null
  example_id: string | null
  is_open: boolean
  edit_protected: boolean
  saved_version: string | null
  recovery_version: string | null
}
export interface ApiError {
  code: string
  message: string
  details?: {
    program_id?: string
    source_version?: string
    line?: number
    failures?: {
      program_id: string
      source_version: string
      target: string
      path: string
      message: string
    }[]
    path?: string
  }
}
export interface AssemblyView {
  program_id: string
  source_version: string
  status: 'assembling' | 'ready' | 'failed'
  image: number[] | null
  pc_to_line: { pc: number; line: number }[] | null
  error: ApiError | null
}
export type LatchName = 'IF/ID' | 'ID/EX' | 'EX/MEM' | 'MEM/WB'
export type StageName = 'IF' | 'ID' | 'EX' | 'MEM' | 'WB'
export interface CycleActivity {
  stage: StageName
  status: 'interpreted' | 'empty' | 'unavailable'
  pc: number | null
  blocks: string[]
}
interface FollowContext {
  session_id: string
  program_id: string
  source_version: string
  origin_step_index: number
  origin_latch: LatchName
  step_index: number
  last_latch: LatchName
  pc: number
  instruction: number
}
export type FollowState = FollowContext &
  (
    | { status: 'following'; reason: null }
    | { status: 'finished'; reason: 'retired' | 'discarded' | 'terminal' }
    | { status: 'unavailable'; reason: 'ambiguous' | 'gap' }
  )
export interface Breakpoint {
  pc: number
  line: number
  latch: LatchName
}
export interface Notice {
  code: string
  section: string
  message: string
}
export interface LatchSnapshot {
  valid: boolean
  pc: number
  instruction: number
  [field: string]: number | boolean
}
export interface Snapshot {
  global_state: number
  image_valid: boolean
  pc: number
  cycle_count: string
  fault_cause: number
  fault_pc: number
  registers: number[]
  if_id: LatchSnapshot
  id_ex: LatchSnapshot
  ex_mem: LatchSnapshot
  mem_wb: LatchSnapshot
  used_count: number
  memory: { address: number; value: number }[]
}
export interface Interpretation {
  cycle_activity: CycleActivity[]
  instruction_locations: { latch: LatchName; pc: number; line: number | null }[]
  changes: {
    previous_step_index: number | null
    register_changes: { register: number; previous: number }[]
    memory_changes: { address: number; previous: number | null }[]
    latch_changes: { latch: LatchName; field: string; previous: number | boolean }[]
    global_changes: { field: string; previous: number | boolean | string }[]
  }
  limitations: Notice[]
}
export interface Observation {
  snapshot: Snapshot
  step_index?: number
  breakpoint_hits?: Breakpoint[]
  interpretation?: Interpretation
}
export interface SessionView {
  session_id: string
  program_id: string
  source_version: string
  source_text: string
  mode: 'run' | 'debug'
  started_at: string
  execution_status: 'ongoing' | 'finished' | 'fault' | 'interrupted' | 'unknown'
  debug_open: boolean
  last_observation: Observation | null
  breakpoints: Breakpoint[]
  outcome: {
    ended_at: string
    interruption_reason: string | null
    failure: { code: string; message: string } | null
  } | null
  evidence: { record_status: string; observation_status: string; limitations: Notice[] }
}
export interface ImageReference {
  program_id: string
  source_version: string
  byte_count: number
}
export interface LiveState {
  board: Board
  works: Work[]
  programs: ProgramView[]
  assemblies: AssemblyView[]
  sessions: SessionView[]
  loaded_image: {
    status: 'loaded' | 'none' | 'unknown'
    program_id: string | null
    source_version: string | null
    byte_count: number | null
  }
  preferences: Preferences
  limitations: { code: string; section: string; message: string }[]
}
export interface StateEvent {
  instance_id: string
  state_revision: number
  type: 'state' | 'update'
  data: Partial<LiveState>
}
export interface Envelope<T> {
  result: T | null
  error: ApiError | null
}
export const blocks = [
  'board',
  'works',
  'programs',
  'assemblies',
  'loaded_image',
  'sessions',
  'preferences',
  'limitations',
] as const
export const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/
export function validateConnection(value: unknown): CoreConnection {
  const d = value as CoreConnection
  if (
    !d ||
    Object.keys(d).sort().join() !==
      ['access_token', 'api_version', 'base_url', 'instance_id'].join() ||
    typeof d.base_url !== 'string' ||
    !/^http:\/\/127\.0\.0\.1:[0-9]{1,5}$/.test(d.base_url) ||
    Number(d.base_url.slice(d.base_url.lastIndexOf(':') + 1)) < 1 ||
    Number(d.base_url.slice(d.base_url.lastIndexOf(':') + 1)) > 65535 ||
    !uuid.test(d.instance_id) ||
    typeof d.access_token !== 'string' ||
    !/^[A-Za-z0-9_-]{32,}$/.test(d.access_token)
  )
    throw new Error('CORE_DISCOVERY_FAILED')
  if (d.api_version !== 1) throw new Error('CORE_INCOMPATIBLE')
  return d
}
export function validateEnvelope<T>(value: unknown): Envelope<T> {
  const e = value as Envelope<T>
  if (
    !e ||
    Object.keys(e).sort().join() !== 'error,result' ||
    (e.error === null
      ? e.result === null
      : e.result !== null ||
        typeof e.error?.code !== 'string' ||
        typeof e.error?.message !== 'string')
  )
    throw new Error('REQUEST_RESULT_UNCONFIRMED')
  return e
}
