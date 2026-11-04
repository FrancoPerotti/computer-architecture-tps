import { CircleCheck, CircleAlert, Info, X } from 'lucide-react'
import { dismissToast, useWorkspace } from './ide-state'
import * as styles from './theme.css'
export function Toasts() {
  const toasts = useWorkspace((state) => state.toasts)
  return (
    <aside className={styles.toastStack} aria-label="Notificaciones">
      {toasts.map((toast) => (
        <section
          key={toast.id}
          className={styles.toast}
          data-kind={toast.kind}
          role={toast.kind === 'error' ? 'alert' : 'status'}
        >
          <span className={styles.toastIcon} aria-hidden="true">
            {toast.kind === 'success' ? (
              <CircleCheck size={18} />
            ) : toast.kind === 'error' ? (
              <CircleAlert size={18} />
            ) : (
              <Info size={18} />
            )}
          </span>
          <div className={styles.toastContent}>
            <p className={styles.toastMessage}>{toast.message}</p>
            {toast.details && (
              <details>
                <summary>Detalles</summary>
                <pre>{toast.details}</pre>
              </details>
            )}
            {toast.action && (
              <button className={styles.menuTrigger} onClick={toast.action}>
                {toast.actionLabel}
              </button>
            )}
          </div>
          <button
            className={styles.toastClose}
            aria-label="Cerrar notificación"
            title="Cerrar notificación"
            onClick={() => dismissToast(toast.id)}
          >
            <X size={14} />
          </button>
        </section>
      ))}
    </aside>
  )
}
