import { blocks, LiveState, StateEvent, uuid } from '../shared/contracts'

export interface AppliedState {
  instance: string | null
  revision: number
  state: LiveState | null
}
export const emptyState: AppliedState = { instance: null, revision: -1, state: null }
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value)
function validateBlocks(data: unknown): asserts data is Partial<LiveState> {
  if (
    !record(data) ||
    Object.keys(data).some((key) => !blocks.includes(key as (typeof blocks)[number]))
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
  for (const key of ['programs', 'assemblies', 'sessions', 'limitations'])
    if (key in data && !Array.isArray(data[key])) throw new Error('EVENT_STREAM_INTERRUPTED')
  if (
    'programs' in data &&
    (data.programs as unknown[]).some(
      (program) =>
        !record(program) ||
        !uuid.test(program.program_id as string) ||
        !uuid.test(program.source_version as string) ||
        typeof program.source_text !== 'string' ||
        typeof program.is_open !== 'boolean' ||
        typeof program.edit_protected !== 'boolean' ||
        !['saved_version', 'recovery_version'].every(
          (field) =>
            program[field] === null ||
            (typeof program[field] === 'string' && uuid.test(program[field] as string)),
        ) ||
        !['source_path', 'example_id'].every(
          (field) => program[field] === null || typeof program[field] === 'string',
        ),
    )
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
  if (
    'assemblies' in data &&
    (data.assemblies as unknown[]).some((assembly) => {
      if (
        !record(assembly) ||
        !uuid.test(assembly.program_id as string) ||
        !uuid.test(assembly.source_version as string)
      )
        return true
      if (assembly.status === 'assembling')
        return assembly.image !== null || assembly.pc_to_line !== null || assembly.error !== null
      if (assembly.status === 'failed')
        return (
          assembly.image !== null ||
          assembly.pc_to_line !== null ||
          !record(assembly.error) ||
          typeof assembly.error.code !== 'string' ||
          typeof assembly.error.message !== 'string'
        )
      return (
        assembly.status !== 'ready' ||
        !Array.isArray(assembly.image) ||
        !assembly.image.every((byte) => Number.isInteger(byte) && byte >= 0 && byte <= 255) ||
        assembly.image.length % 4 !== 0 ||
        !Array.isArray(assembly.pc_to_line) ||
        !assembly.pc_to_line.every(
          (entry) =>
            record(entry) &&
            Number.isInteger(entry.pc) &&
            Number.isInteger(entry.line) &&
            (entry.pc as number) >= 0 &&
            (entry.line as number) >= 1,
        ) ||
        assembly.error !== null
      )
    })
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
  if (
    'works' in data &&
    (!Array.isArray(data.works) ||
      data.works.some(
        (work) =>
          !record(work) ||
          typeof work.work_id !== 'string' ||
          !uuid.test(work.work_id) ||
          !['gui', 'cli'].includes(work.client_type as string) ||
          !Array.isArray(work.pending_commands) ||
          !work.pending_commands.every((command) => typeof command === 'string') ||
          typeof work.owns_board !== 'boolean' ||
          typeof work.debug_open !== 'boolean' ||
          (work.session_id !== null &&
            (typeof work.session_id !== 'string' || !uuid.test(work.session_id))),
      ))
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
  if ('board' in data) {
    const board = data.board
    if (
      !record(board) ||
      !['closed', 'checking', 'checked', 'unreliable'].includes(
        board.connection_status as string,
      ) ||
      typeof board.preparation_required !== 'boolean' ||
      typeof board.recovery_pending !== 'boolean' ||
      ![null, 'gui', 'cli'].includes(board.controller as null | string) ||
      (board.port !== null && typeof board.port !== 'string')
    )
      throw new Error('EVENT_STREAM_INTERRUPTED')
  }
  if (
    'loaded_image' in data &&
    (!record(data.loaded_image) ||
      !['unknown', 'none', 'loaded'].includes(data.loaded_image.status as string))
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
  if (
    'preferences' in data &&
    (!record(data.preferences) ||
      data.preferences.schema_version !== 1 ||
      typeof data.preferences.record_by_default !== 'boolean' ||
      typeof data.preferences.ui_zoom !== 'number' ||
      !Number.isFinite(data.preferences.ui_zoom) ||
      data.preferences.ui_zoom < 0.5 ||
      data.preferences.ui_zoom > 2 ||
      typeof data.preferences.language !== 'string')
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
}
export function applyEvent(
  previous: AppliedState,
  event: StateEvent,
  expectedInstance: string,
): AppliedState {
  if (
    !event ||
    event.instance_id !== expectedInstance ||
    !uuid.test(event.instance_id) ||
    !Number.isSafeInteger(event.state_revision) ||
    event.state_revision < 0
  )
    throw new Error('EVENT_STREAM_INTERRUPTED')
  validateBlocks(event.data)
  if (event.type === 'state') {
    if (previous.instance === expectedInstance && event.state_revision < previous.revision)
      return previous
    if (blocks.some((key) => !(key in event.data))) throw new Error('EVENT_STREAM_INTERRUPTED')
    return {
      instance: event.instance_id,
      revision: event.state_revision,
      state: event.data as LiveState,
    }
  }
  if (event.type !== 'update' || previous.instance !== expectedInstance || previous.state === null)
    throw new Error('EVENT_STREAM_INTERRUPTED')
  if (event.state_revision <= previous.revision) return previous
  if (event.state_revision !== previous.revision + 1) throw new Error('EVENT_STREAM_INTERRUPTED')
  return {
    instance: previous.instance,
    revision: event.state_revision,
    state: { ...previous.state, ...event.data },
  }
}
