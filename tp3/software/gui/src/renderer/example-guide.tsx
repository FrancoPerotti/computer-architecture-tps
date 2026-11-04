import { useEffect, useState, useSyncExternalStore } from 'react'
import type { Observation, SessionView } from '../shared/contracts'
import type { DocumentSync } from './document-sync'
import { useCore } from './core-client'
import { exampleReference, guideAt, originalExample, type ExampleReference } from './examples'
import * as styles from './theme.css'
import { BookOpen } from 'lucide-react'

export function useExampleReference(source: string, exampleId?: string | null) {
  const [reference, setReference] = useState<ExampleReference | null>(null),
    [error, setError] = useState<string | null>(null)
  useEffect(() => {
    let active = true
    setReference((previous) => (exampleId && previous?.example_id === exampleId ? previous : null))
    setError(null)
    void (exampleId ? exampleReference(exampleId) : originalExample(source))
      .then((value) => {
        if (active) setReference(value)
      })
      .catch((error) => {
        if (active) setError(error.message)
      })
    return () => {
      active = false
    }
  }, [source, exampleId])
  return { reference, error }
}
const appearance = (id: string) => id.replace('occurrence-', 'aparición ')
const pc = (value: number) => '0x' + value.toString(16).padStart(8, '0')
export function ExampleDetails({
  reference,
  source,
  observation,
  stale = false,
}: {
  reference: ExampleReference
  source: string
  observation?: Observation | null
  stale?: boolean
}) {
  const original = source === reference.original,
    compatible = reference.memory_profiles.includes(reference.memoryProfile)
  const snapshot = observation?.snapshot,
    row = guideAt(reference, source, snapshot?.cycle_count, observation?.step_index)
  return (
    <div className={styles.exampleGuide} aria-label="Referencia educativa del ejemplo">
      <header className={styles.guideTitle}>
        <span>
          <BookOpen size={20} />
        </span>
        <div>
          <h3>{reference.title}</h3>
          <p>{reference.objective}</p>
        </div>
      </header>
      {!original && (
        <aside className={styles.guideWarning}>
          Referencia del ejemplo original. Modificaste el programa; estos resultados esperados
          corresponden al código original.
        </aside>
      )}
      {!compatible && (
        <aside className={styles.guideWarning}>
          Esta referencia corresponde al perfil {reference.memory_profiles.join(', ')}; el perfil
          actual es {reference.memoryProfile}. La guía no se asocia a esta ejecución.
        </aside>
      )}
      <section className={styles.expectedCard} aria-label="Expectativa del diseño">
        <header>
          <h4>Esperado · diseño</h4>
          <span className={styles.sectionCount}>Al finalizar el programa</span>
        </header>
        <ul className={styles.guideExpectations}>
          {reference.expected_observations.map((text) => (
            <li key={text}>{text}</li>
          ))}
        </ul>
      </section>
      <div className={styles.guideComparison}>
        {row && (
          <section className={styles.guideCycle} aria-label="Guía del ciclo observado">
            <h4>Referencia para el ciclo {row.cycle} · esperado</h4>
            {row.positions.length ? (
              <table className={styles.guideTable}>
                <thead>
                  <tr>
                    <th>Registro</th>
                    <th>PC</th>
                    <th>Aparición</th>
                  </tr>
                </thead>
                <tbody>
                  {row.positions.map((position) => (
                    <tr key={position.latch}>
                      <th scope="row">{position.latch}</th>
                      <td>
                        <code>{pc(position.pc)}</code>
                      </td>
                      <td>{appearance(position.occurrence)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <p>Sin instrucciones válidas en los cuatro registros interetapa.</p>
            )}
            <details className={styles.cycleExplanation}>
              <summary>Explicación del ciclo</summary>
              <p>{row.explanation}</p>
            </details>
          </section>
        )}
        {snapshot && (
          <section
            className={styles.receivedCard}
            aria-label="Captura recibida del ejemplo"
            data-stale={stale}
          >
            <header>
              <h4>
                {stale ? 'Última captura recibida' : 'Captura recibida'} · ciclo{' '}
                {snapshot.cycle_count}
              </h4>
              {stale && <span className={styles.badge}>Sin actualizar</span>}
            </header>
            <table className={styles.guideTable}>
              <thead>
                <tr>
                  <th>Registro</th>
                  <th>Estado</th>
                  <th>PC</th>
                </tr>
              </thead>
              <tbody>
                {(['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB'] as const).map((latch, index) => {
                  const value = snapshot[(['if_id', 'id_ex', 'ex_mem', 'mem_wb'] as const)[index]]
                  return (
                    <tr key={latch}>
                      <th scope="row">{latch}</th>
                      <td>{value.valid ? 'Válido' : 'Sin instrucción'}</td>
                      <td>{value.valid ? <code>{pc(value.pc)}</code> : '—'}</td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </section>
        )}
      </div>
      {snapshot && (
        <p className={styles.sectionIntro}>
          La referencia describe el diseño; los valores recibidos pertenecen a la captura.
        </p>
      )}
      {original && compatible && snapshot && !row && (
        <p className={styles.sectionIntro}>
          La guía no tiene una referencia asociable a esta captura
          {reference.guide.prefix_only ? '; documenta solamente el prefijo del bucle' : ''}. Se
          conservan los datos recibidos.
        </p>
      )}
      <details className={styles.guideTimeline}>
        <summary>Guía por ciclo del ejemplo original</summary>
        <div className={styles.guideTimelineBody}>
          <p className={styles.sectionIntro}>
            Expectativa de diseño, separada de la captura.{' '}
            {reference.guide.prefix_only
              ? 'Es un prefijo: el programa continúa sin terminal automático.'
              : 'Incluye confirmación y drenado hasta el estado terminal.'}
          </p>
          <ul className={styles.guideAssumptions}>
            {reference.guide.assumptions.map((text) => (
              <li key={text}>{text}</li>
            ))}
          </ul>
          <div className={styles.guideTableScroll}>
            <table className={styles.translation}>
              <thead>
                <tr>
                  <th>Ciclo</th>
                  <th>Posiciones válidas esperadas después del flanco</th>
                  <th>Explicación del diseño</th>
                </tr>
              </thead>
              <tbody>
                {reference.guide.cycles.map((cycle) => (
                  <tr
                    key={cycle.cycle}
                    aria-current={row?.cycle === cycle.cycle ? 'step' : undefined}
                  >
                    <td>
                      {cycle.cycle}
                      {row?.cycle === cycle.cycle ? ' · referencia actual' : ''}
                    </td>
                    <td>
                      {cycle.positions.length
                        ? cycle.positions.map((position) => (
                            <div key={position.latch}>
                              {position.latch} · {pc(position.pc)} ·{' '}
                              {appearance(position.occurrence)}
                            </div>
                          ))
                        : 'Pipeline sin instrucciones válidas'}
                    </td>
                    <td>{cycle.explanation}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </details>
    </div>
  )
}

export function SessionExampleGuide({
  source,
  observation,
  exampleId,
  stale = false,
}: {
  source: string
  observation: Observation | null
  exampleId?: string | null
  stale?: boolean
}) {
  const { reference, error } = useExampleReference(source, exampleId)
  if (error) return <p role="alert">{error}</p>
  return reference ? (
    <details className={styles.educationSection}>
      <summary>Guía educativa del ejemplo</summary>
      <ExampleDetails
        reference={reference}
        source={source}
        observation={observation}
        stale={stale}
      />
    </details>
  ) : null
}

export function ExampleReferencePanel({
  document,
  session,
}: {
  document: DocumentSync
  session: SessionView | null
}) {
  const state = useSyncExternalStore(document.subscribe, document.snapshot)
  const synchronized = useCore((core) => core.synchronized)
  const { reference, error } = useExampleReference(
    state.capture.source_text,
    state.program.example_id,
  )
  const belongs =
    session?.program_id === state.program.program_id &&
    session.source_version === state.capture.source_version
  return (
    <section className={styles.referencePanel} aria-label="Acerca del ejemplo">
      <h2>Acerca del ejemplo</h2>
      {error && <p role="alert">{error}</p>}
      {reference ? (
        <ExampleDetails
          reference={reference}
          source={state.capture.source_text}
          observation={belongs ? session?.last_observation : undefined}
          stale={
            !synchronized ||
            session?.execution_status === 'unknown' ||
            session?.outcome?.interruption_reason === 'communication_failure'
          }
        />
      ) : (
        !error && <p>Cargando referencia…</p>
      )}
    </section>
  )
}
