import type { Observation } from '../shared/contracts'
import type { ModuleContent } from './educational-resources'
import * as styles from './theme.css'

const names = {
  IF: 'Búsqueda',
  ID: 'Decodificación',
  EX: 'Ejecución',
  MEM: 'Memoria',
  WB: 'Escritura',
}
export function CycleActivity({
  interpretation,
  modules,
}: {
  interpretation: NonNullable<Observation['interpretation']>
  modules?: Record<string, ModuleContent>
}) {
  return (
    <details className={styles.activitySection}>
      <summary>Actividad inferida del ciclo</summary>
      <div className={styles.activityContent}>
        <p className={styles.sectionIntro}>
          Trabajo del ciclo recién completado, organizado por etapa. Los registros muestran el
          estado posterior al flanco.
        </p>
        <div className={styles.activityStages}>
          {interpretation.cycle_activity.map((row) => (
            <section
              key={row.stage}
              className={styles.activityStage}
              aria-label={`Etapa ${row.stage}`}
            >
              <header>
                <strong className={styles.stageTag}>{row.stage}</strong>
                <div>
                  <h4>{names[row.stage]}</h4>
                  <span className={styles.activityStatus} data-status={row.status}>
                    {row.status === 'empty'
                      ? 'Sin instrucción activa'
                      : row.status === 'unavailable'
                        ? 'No se pudo determinar'
                        : row.blocks.length
                          ? 'Participación inferida'
                          : 'Sin efecto arquitectónico de escritura'}
                  </span>
                </div>
              </header>
              {row.status === 'interpreted' && !!row.blocks.length && (
                <ul className={styles.activityBlocks}>
                  {row.blocks.map((block) => (
                    <li key={block}>{modules?.[block]?.title ?? block}</li>
                  ))}
                </ul>
              )}
            </section>
          ))}
        </div>
        <p className={styles.sectionIntro}>
          La participación se infiere de la captura; no mide señales combinacionales.
        </p>
        {!!interpretation.limitations.length && (
          <aside className={styles.guideWarning}>
            {interpretation.limitations.map((row, index) => (
              <p key={index}>{row.message}</p>
            ))}
          </aside>
        )}
      </div>
    </details>
  )
}
