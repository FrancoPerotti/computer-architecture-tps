import { useCore } from './core-client'
import { SessionExampleGuide } from './example-guide'
import {
  Check,
  AlertTriangle,
  Clock3,
  CirclePause,
  ArrowRight,
  StepForward,
  ScanLine,
} from 'lucide-react'
import type { AssemblyView, LatchName, SourceCapture } from '../shared/contracts'
import { useSessionView } from './session-view'
import { emptyInspection, latchComponents, useInspection } from './inspection'
import { useEducationalResources } from './educational-resources'
import { formatValue } from './ide-workflow'
import * as styles from './theme.css'
import { ValueCell } from './value-cell'
import { InstructionStatus } from './instruction-status'
import { MemoryPanel } from './memory-panel'
import { CycleActivity } from './cycle-activity'

const latches = [
  ['IF/ID', 'if_id'],
  ['ID/EX', 'id_ex'],
  ['EX/MEM', 'ex_mem'],
  ['MEM/WB', 'mem_wb'],
] as const
const widths: Record<string, number> = {
  valid: 1,
  fetch_fault_valid: 1,
  fetch_fault_cause: 3,
  rs1: 5,
  rs2: 5,
  rd: 5,
  reg_write: 1,
  alu_op: 6,
  alu_src: 1,
  result_sel: 2,
  flow_op: 3,
  mem_op: 4,
}
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
export function Results({ sessionId }: { sessionId: string }) {
  const { session, live, error, synchronized, board, pending } = useSessionView(sessionId)
  const exampleId = useCore(
    (state) =>
      state.live.state?.programs.find((program) => program.program_id === session?.program_id)
        ?.example_id,
  )
  const inspection = useInspection((state) => state.items[sessionId] ?? emptyInspection)
  const { resources } = useEducationalResources()
  if (!session)
    return (
      <section className={styles.info}>
        <p role={error ? 'alert' : 'status'}>{error ?? 'Consultando la sesión…'}</p>
      </section>
    )
  const observation = session.last_observation
  const snapshot = observation?.snapshot
  const changes = observation?.interpretation?.changes
  const serialLost = session.outcome?.interruption_reason === 'communication_failure'
  const stale = !synchronized || serialLost || session.execution_status === 'unknown'
  const waiting = pending.some(
    (command) => command === 'debug step' || command === 'debug continue',
  )
  const terminal = session.execution_status === 'finished' || session.execution_status === 'fault'
  const awaitingFirstCapture = session.execution_status === 'ongoing' && session.debug_open
  const rf = snapshot && (
    <details>
      <summary>Banco de registros arquitectónicos · x0–x31</summary>
      <div className={styles.registerGrid}>
        {snapshot.registers.map((value, register) => {
          const changed = changes?.register_changes.find((item) => item.register === register)
          return (
            <ValueCell
              key={register}
              name={`x${register}`}
              value={value}
              changed={!!changed}
              previous={changed?.previous}
            />
          )
        })}
      </div>
    </details>
  )
  const pipeline = snapshot && (
    <div className={styles.latchGrid}>
      {latches.map(([name, key]) => {
        const value = snapshot[key]
        const hit = observation?.breakpoint_hits?.some((item) => item.latch === name)
        const location = observation?.interpretation?.instruction_locations.find(
          (item) => item.latch === name,
        )
        return (
          <section
            key={name}
            aria-label={`Registro ${name}`}
            className={`${hit ? styles.hitLatch : styles.latchCard} ${inspection.component === latchComponents[name] ? styles.selectedLatch : ''}`}
          >
            <h3 className={styles.latchHeading}>
              <span>{name}</span>
              <InstructionStatus
                status={
                  key === 'if_id' && value.fetch_fault_valid
                    ? 'fault'
                    : value.valid
                      ? 'valid'
                      : 'empty'
                }
              />
            </h3>
            {value.valid && location?.line && (
              <div className={styles.latchSource}>
                <code>{session.source_text.split(/\r?\n/)[location.line - 1]}</code>
                <span aria-label={`Línea ${location.line}`} title={`Línea ${location.line}`}>
                  #{location.line}
                </span>
              </div>
            )}
            {key === 'if_id' && value.fetch_fault_valid === true && (
              <p className={styles.muted}>
                Fallo de fetch vigente: {faultNames[Number(value.fetch_fault_cause)]} · PC{' '}
                {formatValue(value.pc, 32, 'hex')}
              </p>
            )}
            {Object.entries(value).map(([field, item]) => {
              const changed = changes?.latch_changes.find(
                (change) => change.latch === (name as LatchName) && change.field === field,
              )
              return (
                <ValueCell
                  key={field}
                  name={`${name}.${field}`}
                  value={item}
                  bits={widths[field] ?? 32}
                  changed={!!changed}
                  previous={changed?.previous}
                />
              )
            })}
          </section>
        )
      })}
    </div>
  )
  return (
    <section className={styles.results} aria-label="Estado del procesador">
      <header className={styles.resultHeader}>
        <div
          className={styles.cycleCount}
          role="group"
          aria-label={`Ciclo observado: ${snapshot?.cycle_count ?? 'sin captura'}`}
          title="Ciclo de reloj observado"
        >
          <Clock3 size={18} aria-hidden="true" />
          <strong>{snapshot?.cycle_count ?? '—'}</strong>
        </div>
      </header>
      {snapshot && (
        <section className={styles.globalState} aria-label="Estado global recibido">
          <h2>Estado global recibido</h2>
          <div className={styles.registerGrid}>
            {(
              [
                ['global_state', snapshot.global_state, 8],
                ['image_valid', snapshot.image_valid, 1],
                ['pc', snapshot.pc, 32],
                ['cycle_count', snapshot.cycle_count, 64],
                ['fault_cause', snapshot.fault_cause, 3],
                ['fault_pc', snapshot.fault_pc, 32],
                ['used_count', snapshot.used_count, 40],
              ] as const
            ).map(([field, value, bits]) => {
              const change = changes?.global_changes.find((item) => item.field === field)
              return (
                <ValueCell
                  key={field}
                  name={field}
                  value={value}
                  bits={bits}
                  changed={!!change}
                  previous={change?.previous}
                />
              )
            })}
          </div>
        </section>
      )}
      {inspection.notice && <p role="status">{inspection.notice}</p>}
      {waiting && <p role="status">Esperando respuesta de la FPGA…</p>}
      {stale && (
        <aside className={styles.persistentWarning} role="alert">
          <strong>
            {!synchronized
              ? 'Se perdió la conexión con el core'
              : serialLost
                ? 'Se perdió la comunicación con la FPGA'
                : 'El resultado de esta sesión quedó sin confirmar'}
          </strong>
          <p>
            {snapshot
              ? `Último estado recibido · ciclo ${snapshot.cycle_count}`
              : 'Todavía no se recibió una captura completa.'}
          </p>
          {serialLost && (
            <p>
              {board?.recovery_pending
                ? 'Recuperando comunicación…'
                : board?.connection_status === 'checked'
                  ? 'Comunicación recuperada. Volvé a cargar el programa para iniciar una nueva depuración.'
                  : 'No se pudo restablecer la comunicación. Reintentá la conexión desde la franja inferior.'}
            </p>
          )}
        </aside>
      )}
      {!live && session && (
        <p className={styles.muted}>
          Registro conservado · esta vista no representa una sesión física activa.
        </p>
      )}
      {error && <p role="alert">{error}</p>}
      {terminal && (
        <h2>
          {session.execution_status === 'finished' ? (
            <Check size={20} />
          ) : (
            <AlertTriangle size={20} />
          )}{' '}
          {session.execution_status === 'finished'
            ? 'Ejecución finalizada'
            : 'Procesador detenido por fault'}
        </h2>
      )}
      {snapshot && (snapshot.global_state === 9 || snapshot.global_state === 11) && (
        <aside className={styles.persistentWarning}>
          Causa: {faultNames[snapshot.fault_cause]} · PC del fault:{' '}
          <code>{formatValue(snapshot.fault_pc, 32, 'hex')}</code>
          {snapshot.global_state === 9 && <p>El pipeline está drenando; todavía no finalizó.</p>}
        </aside>
      )}
      {snapshot?.global_state === 7 && <p>HALT recibido: drenando el pipeline.</p>}
      {!!observation?.breakpoint_hits?.length && (
        <div className={styles.breakpointNotice} role="status" aria-label="Breakpoint alcanzado">
          <CirclePause size={17} aria-hidden="true" />
          <span>Breakpoint</span>
          <ul>
            {observation.breakpoint_hits.map((item) => (
              <li
                key={`${item.line}-${item.latch}`}
                aria-label={`Línea ${item.line} en ${item.latch}`}
              >
                <code title={`Línea ${item.line}`}>#{item.line}</code>
                <ArrowRight size={13} aria-hidden="true" />
                <code>{item.latch}</code>
              </li>
            ))}
          </ul>
        </div>
      )}
      {!snapshot ? (
        <div className={styles.emptyCapture}>
          <span className={styles.emptyCaptureIcon} aria-hidden="true">
            {awaitingFirstCapture ? <StepForward size={22} /> : <ScanLine size={22} />}
          </span>
          <div>
            <h2>{awaitingFirstCapture ? 'Listo para el primer ciclo' : 'Sin captura completa'}</h2>
            <p>
              {awaitingFirstCapture
                ? 'Avanzá un ciclo o continuá la ejecución para recibir la primera captura.'
                : 'Este ensayo no entregó una captura completa del procesador.'}
            </p>
            <p className={styles.emptyCaptureHint}>
              {awaitingFirstCapture
                ? 'Abrir esta vista no ejecuta el procesador.'
                : 'Los valores se muestran solo cuando llega una captura completa.'}
            </p>
          </div>
        </div>
      ) : (
        <>
          {pipeline}
          {rf}
          {observation && <MemoryPanel observation={observation} debugOpen={session.debug_open} />}
        </>
      )}
      <SessionExampleGuide
        source={session.source_text}
        observation={observation}
        exampleId={exampleId}
        stale={stale}
      />
      {observation?.interpretation && (
        <CycleActivity
          interpretation={observation.interpretation}
          modules={resources?.education.modules}
        />
      )}
    </section>
  )
}
export function AssemblyResults({
  assembly,
  capture,
}: {
  assembly: AssemblyView
  capture: SourceCapture
}) {
  const lines = capture.source_text.split(/\r?\n/)
  return (
    <section className={styles.results}>
      <h2>Vista ensamblada</h2>
      <p className={styles.muted}>Versión capturada: {capture.source_version}</p>
      <table className={styles.translation}>
        <thead>
          <tr>
            <th>PC</th>
            <th>Línea</th>
            <th>Instrucción fuente</th>
            <th>Palabra de máquina</th>
          </tr>
        </thead>
        <tbody>
          {assembly.pc_to_line?.map(({ pc, line }) => (
            <tr key={pc}>
              <td>
                <code>{formatValue(pc, 32, 'hex')}</code>
              </td>
              <td>{line}</td>
              <td>
                <code>{lines[line - 1]}</code>
              </td>
              <td>
                <code>
                  {formatValue(
                    (assembly.image?.slice(pc, pc + 4) ?? []).reduce(
                      (sum, byte, index) => sum + byte * 2 ** (8 * index),
                      0,
                    ),
                    32,
                    'hex',
                  )}
                </code>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  )
}
