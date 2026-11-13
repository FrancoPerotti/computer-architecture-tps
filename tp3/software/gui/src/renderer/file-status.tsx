import {
  Clock3,
  FileCode2,
  FileWarning,
  Lock,
  Save,
  ShieldCheck,
  type LucideIcon,
} from 'lucide-react'
import type { DocumentSync } from './document-sync'
import { label } from './documents'
import * as styles from './theme.css'

function Symbol({ icon: Icon, text }: { icon: LucideIcon; text: string }) {
  return (
    <span className={styles.statusSymbol} role="img" aria-label={text} title={text}>
      <Icon size={14} aria-hidden="true" />
    </span>
  )
}
export function FileStatus({
  state,
  changedSinceLoad,
}: {
  state: ReturnType<DocumentSync['snapshot']> | null
  changedSinceLoad: boolean
}) {
  if (!state) return <span className={styles.fileStatus}>Sin archivo activo</span>
  const saved = state.program.saved_version === state.capture.source_version
  const recovered = state.program.recovery_version === state.capture.source_version
  return (
    <span className={styles.fileStatus} aria-label="Estado del archivo">
      <Symbol icon={FileCode2} text="Assembly" />
      <span
        className={styles.statusFileName}
        title={state.program.source_path ?? label(state.program)}
      >
        {label(state.program)}
      </span>
      <Symbol
        icon={saved ? Save : recovered ? ShieldCheck : Clock3}
        text={
          saved ? 'Guardado' : recovered ? 'Recuperación confirmada' : 'Pendiente de autoguardado'
        }
      />
      {state.program.edit_protected && <Symbol icon={Lock} text="Solo lectura" />}
      {changedSinceLoad && <Symbol icon={FileWarning} text="Modificado desde la carga" />}
    </span>
  )
}
