import {
  Bug,
  ChevronDown,
  Hammer,
  Pause,
  Play,
  RotateCcw,
  Square,
  StepForward,
  Upload,
} from 'lucide-react'
import { Menu } from '@base-ui/react/menu'
import type { ReactNode } from 'react'
import { ownWorkId, useCore } from './core-client'
import type { DocumentSync } from './document-sync'
import { actionReason, selectedSession, type ProcessorAction } from './ide-workflow'
import { launchProgram, processorControl, useWorkspace } from './ide-state'
import * as styles from './theme.css'

function Tool({
  label,
  reason,
  onClick,
  children,
  tooltip,
}: {
  tooltip?: string
  label: string
  reason?: string | null
  onClick(): void
  children: ReactNode
}) {
  return (
    <span
      title={tooltip ?? label}
      tabIndex={reason ? 0 : undefined}
      aria-description={reason ?? undefined}
    >
      <button
        className={styles.iconButton}
        aria-label={label}
        disabled={!!reason}
        onClick={onClick}
      >
        {children}
      </button>
    </span>
  )
}
export function ProcessorToolbar({ document }: { document?: DocumentSync }) {
  const { live, synchronized, closing, freshImage } = useCore()
  const { busy, progress, controlling } = useWorkspace()
  const state = live.state,
    workId = ownWorkId()
  const session = selectedSession(state, workId)
  const owner = state?.works.find((work) => work.owns_board)
  const foreign = !!owner && owner.work_id !== workId
  const commands = owner?.pending_commands ?? []
  const capture = document?.snapshot().capture ?? null
  const running =
    commands.includes('run start') ||
    busy === 'run' ||
    (busy === 'combined' && progress === 'Ejecutando…')
  const continuing = commands.includes('debug continue')
  const stepping = commands.includes('debug step') || (controlling && !continuing)
  const reason = (action: ProcessorAction) =>
    actionReason(action, {
      state,
      synchronized,
      closing,
      workId,
      capture,
      busy: !!busy,
      freshImage,
    })
  const unavailable = closing
    ? 'Resolviendo el cierre'
    : !synchronized
      ? 'Sin conexión con el core'
      : foreign
        ? 'La sesión está controlada por CLI u otra ventana'
        : state?.board.connection_status !== 'checked' || state.board.recovery_pending
          ? 'Esperá a recuperar la comunicación'
          : null
  const debug = !!session?.debug_open
  const stepReason =
    unavailable ??
    (session?.execution_status !== 'ongoing'
      ? 'La sesión terminó; reiniciá para volver al inicio'
      : continuing || stepping || busy
        ? 'Hay un paso o control en curso'
        : null)
  const start = (action: ProcessorAction, debugView: 'debug' | 'diagram' = 'debug') => {
    if (document && !reason(action)) void launchProgram(document, action, debugView)
  }
  return (
    <div className={styles.actionBar} aria-label="Acciones del procesador">
      <div>
        <strong>
          {foreign
            ? 'Observando sesión CLI'
            : debug
              ? 'Modo depuración'
              : running
                ? 'Ejecución en curso'
                : 'Edición'}
        </strong>
        <span className={styles.muted}>
          {' '}
          {progress ??
            (debug
              ? continuing
                ? '· Continuando'
                : session.execution_status === 'ongoing'
                  ? null
                  : '· Terminación en inspección'
              : '· Assembly RV32I')}
        </span>
      </div>
      <div className={styles.actionGroup}>
        {debug ? (
          <>
            <Tool
              label="Avanzar un ciclo"
              reason={stepReason}
              onClick={() => {
                void processorControl('step')
              }}
            >
              <StepForward size={19} />
            </Tool>
            <Tool
              label={continuing ? 'Pausar' : 'Continuar'}
              reason={continuing ? unavailable : stepReason}
              onClick={() => {
                void processorControl(continuing ? 'pause' : 'continue')
              }}
            >
              {continuing ? <Pause size={19} /> : <Play size={19} />}
            </Tool>
            <Tool
              label="Reiniciar depuración"
              reason={
                unavailable ??
                (stepping || continuing || busy ? 'Esperá a pausar la depuración' : null)
              }
              onClick={() => {
                void processorControl('restart')
              }}
            >
              <RotateCcw size={19} />
            </Tool>
            <Tool
              label="Detener depuración"
              reason={
                closing || foreign || !synchronized
                  ? 'La sesión no admite este control desde esta ventana'
                  : null
              }
              onClick={() => {
                void processorControl('stop')
              }}
            >
              <Square size={19} />
            </Tool>
          </>
        ) : (
          <>
            <Tool label="Ensamblar" reason={reason('assemble')} onClick={() => start('assemble')}>
              <Hammer size={19} />
            </Tool>
            <Tool label="Cargar" reason={reason('load')} onClick={() => start('load')}>
              <Upload size={19} />
            </Tool>
            <div className={styles.runGroup} role="group" aria-label="Ejecutar programa">
              <Tool
                label={running ? 'Detener ejecución (RESET)' : 'Correr'}
                reason={
                  running
                    ? foreign || closing || !synchronized
                      ? 'La ejecución no admite control desde esta ventana'
                      : null
                    : reason('run')
                }
                onClick={() => {
                  if (running) void processorControl('run-stop')
                  else start('run')
                }}
              >
                {running ? <Square size={19} /> : <Play size={19} />}
              </Tool>
              <Menu.Root>
                <Menu.Trigger
                  className={styles.runDropdown}
                  title="Más opciones"
                  aria-label="Más opciones de ejecución"
                >
                  <ChevronDown size={13} />
                </Menu.Trigger>
                <Menu.Portal>
                  <Menu.Positioner side="bottom" align="end">
                    <Menu.Popup className={styles.menuPopup}>
                      <Menu.Item
                        className={styles.menuItem}
                        disabled={!!reason('combined')}
                        title={reason('combined') ?? undefined}
                        onClick={() => start('combined')}
                      >
                        Ensamblar, cargar y correr
                      </Menu.Item>
                    </Menu.Popup>
                  </Menu.Positioner>
                </Menu.Portal>
              </Menu.Root>
            </div>
            <div className={styles.runGroup} role="group" aria-label="Depurar programa">
              <Tool
                tooltip="Depurar"
                label="Empezar debug"
                reason={reason('debug')}
                onClick={() => start('debug')}
              >
                <Bug size={19} />
              </Tool>
              <Menu.Root>
                <Menu.Trigger
                  className={styles.runDropdown}
                  title="Más opciones de depuración"
                  aria-label="Más opciones de depuración"
                >
                  <ChevronDown size={13} />
                </Menu.Trigger>
                <Menu.Portal>
                  <Menu.Positioner side="bottom" align="end">
                    <Menu.Popup className={styles.menuPopup}>
                      <Menu.Item
                        className={styles.menuItem}
                        disabled={!!reason('debug')}
                        title={reason('debug') ?? undefined}
                        onClick={() => start('debug', 'diagram')}
                      >
                        Depurar con diagrama interactivo
                      </Menu.Item>
                    </Menu.Popup>
                  </Menu.Positioner>
                </Menu.Portal>
              </Menu.Root>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
