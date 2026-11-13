import { useEffect, useState } from 'react'
import { readInstructions } from './instruction-resource'
import { BookOpen, Search } from 'lucide-react'
import * as styles from './theme.css'

import type { Instruction } from './instructions'
const groups = [
  ['all', 'Todas'],
  ['integer', 'Aritmética y lógica'],
  ['memory', 'Memoria'],
  ['flow', 'Saltos'],
  ['control', 'Control'],
]
function group(mnemonic: string): string {
  if (['lb', 'lbu', 'lh', 'lhu', 'lw', 'sb', 'sh', 'sw'].includes(mnemonic)) return 'memory'
  if (['beq', 'bne', 'jal', 'jalr'].includes(mnemonic)) return 'flow'
  return mnemonic === 'halt' ? 'control' : 'integer'
}
export function InstructionCatalog({ instructions }: { instructions: Instruction[] }) {
  const [query, setQuery] = useState(''),
    [category, setCategory] = useState('all')
  const normalize = (value: string) =>
    value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
  const filtered = instructions.filter(
    (item) =>
      (category === 'all' || group(item.mnemonic) === category) &&
      normalize(
        [
          item.mnemonic,
          item.description,
          item.syntax,
          item.example,
          ...item.operands.map((operand) => operand.name + ' ' + operand.description),
          ...item.notes,
        ].join(' '),
      ).includes(normalize(query)),
  )
  return (
    <section className={styles.catalog} aria-label="Catálogo de instrucciones">
      <div className={styles.catalogBody}>
        <header className={styles.catalogHeader}>
          <BookOpen size={22} />
          <div>
            <h2>Catálogo de instrucciones</h2>
            <p>{instructions.length} instrucciones del procesador TP3</p>
          </div>
        </header>
        <div className={styles.catalogTools}>
          <div className={styles.exampleFilters}>
            <label className={styles.searchField}>
              <Search size={16} aria-hidden="true" />
              <input
                aria-label="Buscar instrucción"
                placeholder="Buscar instrucción"
                value={query}
                onChange={(event) => setQuery(event.target.value)}
              />
            </label>
          </div>
          <div className={styles.catalogFilters} aria-label="Familias de instrucciones">
            {groups.map(([id, title]) => (
              <button key={id} aria-pressed={category === id} onClick={() => setCategory(id)}>
                {title}
              </button>
            ))}
          </div>
        </div>
        <div className={styles.catalogEntries}>
          <p className={styles.catalogCount}>
            {filtered.length} de {instructions.length} instrucciones
          </p>
          <div className={styles.catalogGrid}>
            {filtered.map((item) => (
              <article
                key={item.mnemonic}
                className={styles.instructionCard}
                aria-label={item.mnemonic}
              >
                <header>
                  <h3>
                    <code>{item.mnemonic}</code>
                  </h3>
                  <small>{groups.find(([id]) => id === group(item.mnemonic))?.[1]}</small>
                </header>
                <div className={styles.instructionIntro}>
                  <code className={styles.instructionSyntax}>{item.syntax}</code>
                  <p>{item.description}</p>
                </div>
                <div className={styles.instructionDetails}>
                  <section>
                    <h4>Parámetros</h4>
                    {item.operands.length ? (
                      <dl className={styles.instructionOperands}>
                        {item.operands.map((operand) => (
                          <div key={operand.name}>
                            <dt>
                              <code>{operand.name}</code>
                            </dt>
                            <dd>{operand.description}</dd>
                          </div>
                        ))}
                      </dl>
                    ) : (
                      <p>No recibe operandos.</p>
                    )}
                  </section>
                  <section>
                    <h4>Ejemplo de uso</h4>
                    <pre className={styles.instructionExample}>
                      <code>{item.example}</code>
                    </pre>
                  </section>
                </div>
                {!!item.notes.length && (
                  <ul className={styles.instructionNotes}>
                    {item.notes.map((note) => (
                      <li key={note}>{note}</li>
                    ))}
                  </ul>
                )}
              </article>
            ))}
          </div>
          {!filtered.length && (
            <p className={styles.muted}>No hay instrucciones para esta búsqueda.</p>
          )}
        </div>
      </div>
    </section>
  )
}

export function InstructionCatalogPanel() {
  const [instructions, setInstructions] = useState<Instruction[] | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [attempt, setAttempt] = useState(0)
  useEffect(() => {
    let active = true
    setError(null)
    void readInstructions()
      .then((value) => {
        if (active) setInstructions(value)
      })
      .catch((problem) => {
        if (active) setError((problem as Error).message)
      })
    return () => {
      active = false
    }
  }, [attempt])
  if (instructions) return <InstructionCatalog instructions={instructions} />
  return (
    <section className={styles.catalog} aria-label="Catálogo de instrucciones">
      <div className={styles.catalogBody}>
        <h2>Catálogo de instrucciones</h2>
        {error ? (
          <>
            <p role="alert">{error}</p>
            <button
              className={styles.secondaryButton}
              onClick={() => setAttempt((value) => value + 1)}
            >
              Reintentar carga del catálogo
            </button>
          </>
        ) : (
          <p role="status">Cargando catálogo…</p>
        )}
      </div>
    </section>
  )
}
