import { Dialog } from '@base-ui/react/dialog'
import { X } from 'lucide-react'
import type { ReactNode } from 'react'
import * as styles from './theme.css'

export function Modal({
  label,
  title = label,
  onCancel,
  children,
  open = true,
  persist = false,
}: {
  label: string
  title?: string
  onCancel(): void
  children: ReactNode
  open?: boolean
  persist?: boolean
}) {
  return (
    <Dialog.Root
      open={open}
      disablePointerDismissal
      onOpenChange={(open) => {
        if (!open) onCancel()
      }}
    >
      <Dialog.Portal keepMounted={persist}>
        <Dialog.Backdrop className={styles.modal} style={open ? undefined : { display: 'none' }} />
        <Dialog.Popup
          className={`${styles.modalBody} ${styles.dialogPopup}`}
          style={open ? undefined : { display: 'none' }}
          aria-label={label}
        >
          <header className={styles.dialogHeader}>
            <Dialog.Title>{title}</Dialog.Title>
            <Dialog.Close
              className={styles.iconButton}
              style={{ margin: 0, padding: 0 }}
              aria-label="Cerrar diálogo"
            >
              <X size={16} />
            </Dialog.Close>
          </header>
          <div className={styles.dialogScroller}>
            <div className={styles.dialogContent}>{children}</div>
          </div>
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  )
}
