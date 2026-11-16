import type { LatchSnapshot, Snapshot } from '../shared/contracts'
import { formatValue } from './ide-workflow'
import * as styles from './theme.css'

const faultNames = [
  'INSTRUCTION_ADDRESS_MISALIGNED',
  'INSTRUCTION_ACCESS_FAULT',
  'ILLEGAL_INSTRUCTION',
  'RESERVED',
  'LOAD_ADDRESS_MISALIGNED',
  'LOAD_ACCESS_FAULT',
  'STORE_ADDRESS_MISALIGNED',
  'STORE_ACCESS_FAULT',
]

export function FetchCandidateDetails({ latch }: { latch: LatchSnapshot }) {
  return (
    <span className={styles.muted}>
      Fetch pendiente de confirmación · PC <code>{formatValue(latch.pc, 32, 'hex')}</code> ·{' '}
      {faultNames[Number(latch.fetch_fault_cause)]}
    </span>
  )
}

export function ConfirmedFault({ snapshot }: { snapshot: Snapshot }) {
  // Protocol: global fault metadata is active only in FAULT_DRAIN_AUTO, FAULT_DRAIN_STEP or FAULT.
  const draining = snapshot.global_state === 0x08 || snapshot.global_state === 0x09
  if (!draining && snapshot.global_state !== 0x0b) return null
  return (
    <aside className={styles.confirmedFault} role="alert">
      <strong>{draining ? 'Fallo confirmado · drenando el pipeline' : 'Fallo confirmado'}</strong>
      <span>
        Causa: {faultNames[snapshot.fault_cause]} · PC del fault:{' '}
        <code>{formatValue(snapshot.fault_pc, 32, 'hex')}</code>
      </span>
    </aside>
  )
}
