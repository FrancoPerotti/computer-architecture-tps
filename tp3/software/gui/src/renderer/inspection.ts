import { create } from 'zustand'
import type { FollowState, LatchName, SessionView } from '../shared/contracts'
import { request, useCore } from './core-client'

export const latchComponents: Record<LatchName, string> = {
  'IF/ID': 'latch.if_id',
  'ID/EX': 'latch.id_ex',
  'EX/MEM': 'latch.ex_mem',
  'MEM/WB': 'latch.mem_wb',
}
export const latchKeys = {
  'IF/ID': 'if_id',
  'ID/EX': 'id_ex',
  'EX/MEM': 'ex_mem',
  'MEM/WB': 'mem_wb',
} as const
export const followReasons = {
  retired: 'La aparición terminó su recorrido.',
  discarded: 'La aparición fue descartada.',
  terminal: 'Terminó la sesión de esta aparición.',
  ambiguous: 'No se puede justificar la continuidad de esta aparición.',
  gap: 'Se perdió la continuidad de las capturas. No se eligió otra aparición.',
}
export interface ConnectionSelection {
  id: string
  name: string
  route: string
  description: string
}
export interface Inspection {
  component: string | null
  latch: LatchName | null
  follow: FollowState | null
  notice: string | null
  epoch: number
  centre: number
  starting: boolean
  connection: ConnectionSelection | null
}
export const emptyInspection: Inspection = {
  component: null,
  latch: null,
  follow: null,
  notice: null,
  epoch: 0,
  centre: 0,
  starting: false,
  connection: null,
}
export const useInspection = create<{ items: Record<string, Inspection> }>(() => ({ items: {} }))
const pending = new Map<string, number>()
function current(id: string): Inspection {
  return useInspection.getState().items[id] ?? emptyInspection
}
function update(id: string, value: Partial<Inspection>): void {
  useInspection.setState((state) => ({
    items: { ...state.items, [id]: { ...current(id), ...value } },
  }))
}
export function pickComponent(id: string, component: string): void {
  const previous = current(id)
  const latch =
    (Object.keys(latchComponents) as LatchName[]).find(
      (key) => latchComponents[key] === component,
    ) ?? null
  update(id, {
    component,
    latch,
    follow: null,
    notice: null,
    epoch: previous.epoch + 1,
    centre: previous.centre + 1,
    starting: false,
    connection: null,
  })
}
export function pickConnection(id: string, connection: ConnectionSelection): void {
  const previous = current(id)
  update(id, {
    connection,
    component: null,
    latch: null,
    follow: null,
    notice: null,
    starting: false,
    epoch: previous.epoch + 1,
  })
}
export function stopFollowing(id: string): void {
  const value = current(id)
  update(id, { follow: null, notice: null, epoch: value.epoch + 1, starting: false })
}
function applyFollow(id: string, value: FollowState, epoch: number): void {
  const previous = current(id)
  if (previous.epoch !== epoch) return
  update(id, {
    follow: value,
    latch: value.last_latch,
    component: latchComponents[value.last_latch],
    notice: value.reason ? followReasons[value.reason] : null,
    starting: false,
    centre: previous.centre + (previous.latch === value.last_latch ? 0 : 1),
  })
}
export async function followOccurrence(session: SessionView, latch: LatchName): Promise<void> {
  pickComponent(session.session_id, latchComponents[latch])
  const id = session.session_id,
    epoch = current(id).epoch,
    instance = useCore.getState().live.instance
  update(id, { notice: 'Iniciando seguimiento de esta aparición…', starting: true })
  try {
    const value = await request<FollowState>('POST', 'interpretation/follow', {
      selection: { session_id: id, step_index: session.last_observation?.step_index, latch },
    })
    if (useCore.getState().live.instance !== instance) return
    applyFollow(id, value, epoch)
    advance(id)
  } catch (error) {
    if (current(id).epoch === epoch)
      update(id, { notice: (error as Error).message, starting: false })
  }
}
function advance(id: string): void {
  const selected = current(id),
    state = useCore.getState(),
    session = state.live.state?.sessions.find((session) => session.session_id === id)
  const follow = selected.follow
  if (selected.starting && (!state.synchronized || !session || !session.debug_open)) {
    update(id, { starting: false, notice: followReasons.gap, epoch: selected.epoch + 1 })
    return
  }
  if (!follow || follow.status !== 'following') return
  if (!state.synchronized || !session || !session.debug_open) {
    const reason =
      !state.synchronized || session?.outcome?.interruption_reason === 'communication_failure'
        ? 'gap'
        : 'terminal'
    update(id, {
      follow: {
        ...follow,
        status: reason === 'gap' ? 'unavailable' : 'finished',
        reason,
      } as FollowState,
      notice: followReasons[reason],
      epoch: selected.epoch + 1,
    })
    return
  }
  if (pending.has(id)) return
  if ((session.last_observation?.step_index ?? 0) <= follow.step_index) return
  const epoch = selected.epoch,
    instance = state.live.instance
  pending.set(id, epoch)
  void request<FollowState>('POST', 'interpretation/follow', { follow })
    .then((value) => {
      if (useCore.getState().live.instance === instance) applyFollow(id, value, epoch)
    })
    .catch((error) => {
      if (current(id).epoch === epoch)
        update(id, {
          follow: { ...follow, status: 'unavailable', reason: 'gap' },
          notice: (error as Error).message,
        })
    })
    .finally(() => {
      if (pending.get(id) === epoch) pending.delete(id)
      if (current(id).follow?.status === 'following') advance(id)
    })
}
// One observer per application, independent of tabs and splits. No board commands.
useCore.subscribe(() => {
  for (const id of Object.keys(useInspection.getState().items)) advance(id)
})
