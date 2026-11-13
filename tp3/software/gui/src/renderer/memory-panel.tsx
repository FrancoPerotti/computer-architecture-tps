import { useState } from 'react'
import { Database, Info, Search, X } from 'lucide-react'
import type { Observation } from '../shared/contracts'
import { ValueCell } from './value-cell'
import * as styles from './theme.css'

export function MemoryPanel({
  observation,
  debugOpen,
}: {
  observation: Observation
  debugOpen: boolean
}) {
  const [query, setQuery] = useState('')
  const { snapshot, interpretation } = observation
  const matches = snapshot.memory.filter(
    (item) =>
      !query ||
      String(item.address).includes(query) ||
      ('0x' + item.address.toString(16)).includes(query.toLowerCase()),
  )
  return (
    <details aria-label="Memoria observada" className={styles.memoryPanel} open={!debugOpen}>
      <summary>
        <span>Memoria</span>
        <span className={styles.sectionCount}>{snapshot.used_count} bytes observados</span>
      </summary>
      <div className={styles.memoryBody}>
        <div className={styles.memoryTools}>
          <label className={styles.searchField}>
            <Search size={16} aria-hidden="true" />
            <input
              aria-label="Filtrar dirección de memoria"
              placeholder="Buscar dirección (0x00 o decimal)"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
            />
          </label>
          {query && (
            <button
              className={styles.iconButton}
              aria-label="Limpiar filtro de memoria"
              title="Limpiar filtro"
              onClick={() => setQuery('')}
            >
              <X size={16} />
            </button>
          )}
          <span
            className={styles.memoryHint}
            role="img"
            tabIndex={0}
            aria-label="Solo se muestran bytes recibidos; las direcciones no observadas no se presumen cero."
            title="Solo se muestran bytes recibidos; las direcciones no observadas no se presumen cero."
          >
            <Info size={16} />
          </span>
        </div>
        {matches.length ? (
          <div className={styles.registerGrid}>
            {matches.map((item) => {
              const change = interpretation?.changes?.memory_changes.find(
                (change) => change.address === item.address,
              )
              return (
                <ValueCell
                  key={item.address}
                  name={`mem[0x${item.address.toString(16)}]`}
                  value={item.value}
                  bits={8}
                  changed={!!change}
                  previous={change?.previous}
                />
              )
            })}
          </div>
        ) : (
          <div className={styles.memoryEmpty}>
            <Database size={26} aria-hidden="true" />
            <div>
              <h4>{snapshot.memory.length ? 'Sin coincidencias' : 'Sin datos de memoria'}</h4>
              <p>
                {snapshot.memory.length
                  ? 'Probá otra dirección o limpiá el filtro.'
                  : 'La captura no incluye bytes observados.'}
              </p>
            </div>
          </div>
        )}
      </div>
    </details>
  )
}
