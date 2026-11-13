import { useState } from 'react'
import { ChevronRight, Search } from 'lucide-react'
import type { ExampleEntry } from './examples'
import { reportError } from './ide-state'
import { Modal } from './modal'
import * as styles from './theme.css'

const categories = [
  ['all', 'Grupo'],
  ['intro', 'Primeros ejemplos'],
  ['instruction', 'Instrucciones'],
  ['interaction', 'Interacciones'],
  ['control', 'Control de flujo'],
  ['boundary', 'Casos de borde'],
]
const normalize = (text: string) =>
  text
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()

export function ExamplePicker({
  open,
  examples,
  onChoose,
  onClose,
}: {
  open: boolean
  examples: ExampleEntry[]
  onChoose(id: string): Promise<void>
  onClose(): void
}) {
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('all')
  const [opening, setOpening] = useState<string | null>(null)
  const visible = examples.filter(
    (entry) =>
      (category === 'all' || entry.category === category) &&
      normalize(
        [entry.title, entry.objective, ...entry.related_instruction_ids].join(' '),
      ).includes(normalize(query)),
  )
  async function choose(id: string) {
    if (opening !== null) return
    setOpening(id)
    try {
      await onChoose(id)
      onClose()
    } catch (error) {
      reportError(error)
    } finally {
      setOpening(null)
    }
  }
  return (
    <Modal label="Abrir ejemplo" open={open} onCancel={onClose}>
      <div className={styles.exampleFilters}>
        <label className={styles.searchField}>
          <Search size={16} aria-hidden="true" />
          <input
            aria-label="Buscar ejemplo"
            value={query}
            placeholder="Buscar ejemplo"
            onChange={(event) => setQuery(event.target.value)}
          />
        </label>
        <select
          aria-label="Grupo de ejemplos"
          value={category}
          onChange={(event) => setCategory(event.target.value)}
        >
          {categories.map(([id, title]) => (
            <option key={id} value={id}>
              {title}
            </option>
          ))}
        </select>
      </div>
      <section className={styles.exampleResults}>
        <p className={styles.muted}>
          {visible.length} de {examples.length} ejemplos
        </p>
        <div className={styles.exampleList} role="list" aria-label="Ejemplos disponibles">
          {visible.map((example) => (
            <button
              key={example.example_id}
              aria-label={example.title}
              disabled={opening !== null}
              aria-busy={opening === example.example_id}
              onClick={() => {
                void choose(example.example_id)
              }}
            >
              <span style={{ flex: 1 }}>
                <span className={styles.exampleName}>
                  <strong>{example.title}</strong>
                  <code>{example.source_path.split('/').at(-1)}</code>
                </span>
                <p>{example.objective}</p>
              </span>
              <ChevronRight size={17} aria-hidden="true" />
            </button>
          ))}
          {!visible.length && <p>No hay ejemplos para esta búsqueda.</p>}
        </div>
      </section>
    </Modal>
  )
}
