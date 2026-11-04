import { useEffect, useRef, useState, type ReactNode } from 'react'
import { Crosshair, Pin, Route, Unlink, CircleCheck } from 'lucide-react'
import type { LatchName, ProcessorProfile, Snapshot } from '../shared/contracts'
import { request, useCore } from './core-client'
import { GraphViewerAdapter } from './graph-adapter'
import { useEducationalResources } from './educational-resources'
import {
  emptyInspection,
  followOccurrence,
  latchComponents,
  latchKeys,
  pickComponent,
  pickConnection,
  stopFollowing,
  useInspection,
} from './inspection'
import { useSessionView } from './session-view'
import { ValueCell } from './value-cell'
import { SessionExampleGuide } from './example-guide'
import * as styles from './theme.css'

function fieldValue(snapshot: Snapshot, path: string): number | string | boolean | undefined {
  let value: unknown = snapshot
  for (const key of path.split('.'))
    value = value && typeof value === 'object' ? (value as Record<string, unknown>)[key] : undefined
  return typeof value === 'number' || typeof value === 'boolean' || typeof value === 'string'
    ? value
    : undefined
}
const displayField = (path: string) =>
  path.startsWith('registers.') ? `x${path.split('.')[1]}` : path
function DiagramAction({
  label,
  reason,
  onClick,
  children,
}: {
  label: string
  reason?: string | null
  onClick(): void
  children: ReactNode
}) {
  return (
    <span
      className={styles.diagramAction}
      title={reason ?? label}
      tabIndex={reason ? 0 : undefined}
      aria-description={reason ?? undefined}
    >
      <button
        className={styles.iconButton}
        aria-label={label}
        title={reason ?? label}
        disabled={!!reason}
        onClick={onClick}
      >
        {children}
      </button>
    </span>
  )
}

export function SessionDiagram({ sessionId, onFocus }: { sessionId: string; onFocus?(): void }) {
  const { session, live, error, synchronized, board, stale } = useSessionView(sessionId)
  const exampleId = useCore(
    (state) =>
      state.live.state?.programs.find((program) => program.program_id === session?.program_id)
        ?.example_id,
  )
  const { resources, resourceError } = useEducationalResources()
  const selected = useInspection((state) => state.items[sessionId] ?? emptyInspection)
  const component = selected.connection ? '' : (selected.component ?? ''),
    module = resources?.education.modules[component]
  const container = useRef<HTMLDivElement>(null),
    adapter = useRef<GraphViewerAdapter | null>(null)
  const focusCallback = useRef(onFocus)
  focusCallback.current = onFocus
  const [graphError, setGraphError] = useState<string | null>(null),
    [ready, setReady] = useState(false)
  useEffect(() => {
    if (!resources || !session || !container.current) return
    setGraphError(null)
    let active = true
    const graph = new GraphViewerAdapter({
      select: (block) => pickComponent(sessionId, block),
      connection: (value) => pickConnection(sessionId, value),
      error: setGraphError,
      ready: () => setReady(true),
      activate: () => focusCallback.current?.(),
    })
    adapter.current = graph
    void request<{ processor_profile: ProcessorProfile }>('GET', 'core/info')
      .then((info) => {
        if (active && container.current)
          graph.mount(container.current, resources, info.processor_profile)
      })
      .catch((error) => {
        if (active) setGraphError(error.message)
      })
    return () => {
      active = false
      graph.dispose()
      adapter.current = null
      setReady(false)
    }
  }, [resources, session?.session_id])
  useEffect(() => {
    if (session)
      adapter.current?.setObservation({
        session_id: session.session_id,
        program_id: session.program_id,
        source_version: session.source_version,
        observation: session.last_observation,
        stale: stale || !live,
      })
  }, [session, stale, live, ready])
  useEffect(() => {
    if (component) adapter.current?.selectComponent(component, selected.centre > 0)
  }, [component, selected.centre, ready])
  const observation = session?.last_observation,
    snapshot = observation?.snapshot,
    changes = observation?.interpretation?.changes
  const latch =
    selected.latch ??
    (Object.keys(latchComponents) as LatchName[]).find(
      (name) => latchComponents[name] === component,
    ) ??
    null
  const followReason =
    !session || !live || !session.debug_open || session.mode !== 'debug'
      ? 'Iniciá una depuración para seguir una instrucción.'
      : !synchronized || stale
        ? 'Esperá a recuperar la conexión con la sesión.'
        : !snapshot
          ? 'Avanzá un ciclo para recibir la primera captura.'
          : !latch
            ? 'Elegí IF/ID, ID/EX, EX/MEM o MEM/WB en Componente.'
            : !snapshot[latchKeys[latch]].valid
              ? 'El registro está vacío. Elegí otro registro o avanzá un ciclo.'
              : selected.starting
                ? 'Iniciando seguimiento…'
                : null
  const following = selected.follow?.status === 'following'
  const followStatus = following
    ? 'Siguiendo una aparición'
    : selected.follow
      ? 'Seguimiento finalizado'
      : 'Observación fija'
  const fields =
    resources?.profile.observable_fields[component]?.filter((field) => !field.path.includes('*')) ??
    []
  const changeFor = (path: string) => {
    if (path.startsWith('registers.'))
      return changes?.register_changes.find((row) => row.register === Number(path.split('.')[1]))
    const [key, field] = path.split('.')
    if (field) {
      const name = (Object.keys(latchKeys) as LatchName[]).find((name) => latchKeys[name] === key)
      return changes?.latch_changes.find((row) => row.latch === name && row.field === field)
    }
    return changes?.global_changes.find((row) => row.field === path)
  }
  return (
    <section
      className={styles.graphView}
      aria-label="Diagrama de la sesión"
      onFocusCapture={() => focusCallback.current?.()}
      onPointerDownCapture={() => focusCallback.current?.()}
    >
      <header className={styles.graphHeader}>
        <strong>Pipeline</strong>
        <span>
          {snapshot
            ? `${stale || !live ? 'Último estado recibido' : 'Ciclo observado'} · ${snapshot.cycle_count}`
            : 'Sin captura recibida'}
        </span>
        <span style={{ color: styles.colors.functional }}>● Participación inferida</span>
        <span style={{ color: styles.colors.accent }}>● Selección</span>
      </header>
      {(error || resourceError || graphError) && (
        <p className={styles.error} role="alert">
          {error ?? resourceError ?? graphError}
        </p>
      )}
      {stale && session && (
        <aside className={styles.persistentWarning} role="alert">
          <strong>
            {!synchronized
              ? 'Se perdió la conexión con el core'
              : session.outcome?.interruption_reason === 'communication_failure'
                ? 'Se perdió la comunicación con la FPGA'
                : 'El resultado quedó sin confirmar'}
          </strong>
          <p>
            {snapshot
              ? `Último estado recibido · ciclo ${snapshot.cycle_count}`
              : 'Todavía no se recibió una captura completa.'}
            {board?.recovery_pending ? ' Recuperando comunicación…' : ''}
          </p>
        </aside>
      )}
      {!live && session && (
        <p className={styles.muted}>
          Registro conservado · no representa una sesión física activa.
        </p>
      )}
      <div className={styles.graphCanvas}>
        <div ref={container} style={{ position: 'absolute', inset: 0 }} />
        {!ready && !graphError && (
          <p
            role="status"
            style={{ position: 'absolute', left: 16, top: 10, pointerEvents: 'none' }}
          >
            Abriendo el circuito completo…
          </p>
        )}
      </div>
      <section className={styles.graphInspector} aria-label="Inspector del circuito">
        <div className={styles.inspectorControls}>
          <select
            aria-label="Componente del circuito"
            value={component}
            onChange={(event) => pickComponent(sessionId, event.target.value)}
          >
            <option value="" disabled>
              Componente
            </option>
            {resources &&
              Object.entries(resources.education.modules).map(([id, entry]) => (
                <option key={id} value={id}>
                  {entry.title}
                </option>
              ))}
          </select>
          <DiagramAction
            label="Centrar componente"
            reason={!component ? 'Seleccioná un componente del circuito.' : null}
            onClick={() => adapter.current?.selectComponent(component, true)}
          >
            <Crosshair size={18} />
          </DiagramAction>
          {following ? (
            <DiagramAction label="Dejar de seguir" onClick={() => stopFollowing(sessionId)}>
              <Unlink size={18} />
            </DiagramAction>
          ) : (
            <DiagramAction
              label="Seguir esta instrucción"
              reason={followReason}
              onClick={() => {
                if (session && latch) void followOccurrence(session, latch)
              }}
            >
              <Route size={18} />
            </DiagramAction>
          )}
          <span
            className={styles.inspectionStatus}
            role="img"
            aria-label={followStatus}
            title={followStatus}
            data-following={following}
          >
            {following ? (
              <Route size={16} aria-hidden="true" />
            ) : selected.follow ? (
              <CircleCheck size={16} aria-hidden="true" />
            ) : (
              <Pin size={16} aria-hidden="true" />
            )}
          </span>
        </div>
        {selected.notice && <p role="status">{selected.notice}</p>}
        {module && <p>{module.description}</p>}
        {selected.connection && (
          <div>
            <strong>{selected.connection.name}</strong>
            <p>{selected.connection.route}</p>
            <p style={{ whiteSpace: 'pre-line' }}>{selected.connection.description}</p>
            <p className={styles.muted}>
              Explicación conceptual de la conexión. UART no transmite su valor; no se reconstruyen
              señales adicionales.
            </p>
          </div>
        )}
        {latch === 'IF/ID' && snapshot?.if_id.fetch_fault_valid === true && (
          <p>Hay un candidato de fetch independiente de valid. Se conserva su causa recibida.</p>
        )}
        {!snapshot ? (
          <p>Sin captura completa. Los valores no se presumen cero.</p>
        ) : !!fields.length || component === 'mem.data_memory' ? (
          <div className={styles.registerGrid}>
            {fields.map((field) => {
              const value = fieldValue(snapshot, field.path),
                change = changeFor(field.path)
              return value === undefined ? (
                <p key={field.path}>Campo no recibido: {field.path}</p>
              ) : (
                <ValueCell
                  key={field.path}
                  name={displayField(field.path)}
                  value={value}
                  bits={field.bits}
                  changed={!!change}
                  previous={change?.previous}
                />
              )
            })}
            {component === 'mem.data_memory' &&
              snapshot.memory.map((row) => {
                const change = changes?.memory_changes.find((item) => item.address === row.address)
                return (
                  <ValueCell
                    key={row.address}
                    name={`mem[0x${row.address.toString(16)}]`}
                    value={row.value}
                    bits={8}
                    changed={!!change}
                    previous={change?.previous}
                  />
                )
              })}
          </div>
        ) : null}
        {snapshot &&
          component &&
          !selected.connection &&
          !fields.length &&
          component !== 'mem.data_memory' && (
            <p className={styles.muted}>
              Este componente no publica valores directos por UART. No se reconstruyen señales
              adicionales.
            </p>
          )}
        {component === 'mem.data_memory' && (
          <p className={styles.muted}>
            Solo se muestran direcciones recibidas, incluidos bytes cero escritos. Las direcciones
            ausentes no se presumen cero.
          </p>
        )}
        {!!observation?.interpretation?.limitations.length && (
          <details>
            <summary>Límites de la interpretación</summary>
            {observation.interpretation.limitations.map((row, index) => (
              <p key={index}>{row.message}</p>
            ))}
          </details>
        )}
        {session && (
          <SessionExampleGuide
            source={session.source_text}
            observation={observation ?? null}
            exampleId={exampleId}
            stale={stale || !live}
          />
        )}
      </section>
    </section>
  )
}
