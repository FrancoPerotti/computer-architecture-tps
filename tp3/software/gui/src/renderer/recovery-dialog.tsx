import type { ProgramView } from '../shared/contracts'
import { label } from './documents'
import { Modal } from './modal'
import * as styles from './theme.css'

export function RecoveryDialog({
  open,
  programs,
  onClose,
  onRecover,
  onDiscard,
}: {
  open: boolean
  programs: ProgramView[]
  onClose(): void
  onRecover(id: string): void
  onDiscard(id: string): void
}) {
  return (
    <Modal label="Borradores recuperables" open={open} onCancel={onClose}>
      <p className={styles.muted}>
        Programas cerrados con cambios sin guardar en un archivo. Los ejemplos intactos no aparecen
        aquí.
      </p>
      <div className={styles.recoveryList}>
        {programs.map((program) => (
          <div className={styles.recoveryRow} key={program.program_id}>
            <span>{label(program)}</span>
            <button
              className={styles.secondaryButton}
              aria-label={`Recuperar ${label(program)}`}
              onClick={() => onRecover(program.program_id)}
            >
              Recuperar
            </button>
            <button
              className={styles.menuTrigger}
              aria-label={`Descartar ${label(program)}`}
              onClick={() => onDiscard(program.program_id)}
            >
              Descartar
            </button>
          </div>
        ))}
      </div>
      {!programs.length && <p>No hay borradores pendientes de recuperar.</p>}
    </Modal>
  )
}
