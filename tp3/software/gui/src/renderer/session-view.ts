import { useEffect, useState } from 'react'
import type { SessionView } from '../shared/contracts'
import { request, useCore } from './core-client'

export function useSessionView(sessionId: string) {
  const live = useCore((state) =>
    state.live.state?.sessions.find((session) => session.session_id === sessionId),
  )
  const synchronized = useCore((state) => state.synchronized),
    instance = useCore((state) => state.live.instance)
  const board = useCore((state) => state.live.state?.board)
  const work = useCore((state) =>
    state.live.state?.works.find((work) => work.session_id === sessionId),
  )
  const [received, setReceived] = useState<SessionView | null>(null),
    [error, setError] = useState<string | null>(null)
  useEffect(() => {
    let active = true
    setReceived((previous) =>
      previous
        ? {
            ...previous,
            debug_open: false,
            execution_status:
              previous.execution_status === 'finished' || previous.execution_status === 'fault'
                ? previous.execution_status
                : 'unknown',
          }
        : null,
    )
    void request<SessionView>('GET', `session/show?session_id=${sessionId}`)
      .then((value) => {
        if (active) {
          setReceived(value)
          setError(null)
        }
      })
      .catch((problem) => {
        if (active) setError(problem.message)
      })
    return () => {
      active = false
    }
  }, [sessionId, instance])
  useEffect(() => {
    if (live) setReceived(live)
  }, [live])
  const session = live ?? (received?.session_id === sessionId ? received : null)
  const stale =
    !synchronized ||
    session?.outcome?.interruption_reason === 'communication_failure' ||
    session?.execution_status === 'unknown'
  return { session, live, error, synchronized, board, pending: work?.pending_commands ?? [], stale }
}
