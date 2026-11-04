import { useEffect, useRef, useState } from 'react'
import { Languages, NotebookPen, UserRound, ZoomIn } from 'lucide-react'
import type { Preferences } from '../shared/contracts'
import { request, useCore } from './core-client'
import * as styles from './theme.css'

export function PreferencesPanel() {
  const limitations = useCore((state) => state.live.state?.limitations)
  const confirmed = useCore((state) => state.live.state?.preferences)
  const [author, setAuthor] = useState(confirmed?.default_author ?? '')
  const [record, setRecord] = useState(confirmed?.record_by_default ?? true)
  const [zoom, setZoom] = useState<number | null>(null)
  const [problem, setProblem] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)
  const pending = useRef<Partial<Preferences>>({})
  const inFlight = useRef(false)
  async function pump() {
    if (inFlight.current || !Object.keys(pending.current).length) return
    inFlight.current = true
    setSaving(true)
    const patch = pending.current
    pending.current = {}
    try {
      await request('POST', 'preferences/update', patch)
      setProblem(null)
    } catch (error) {
      pending.current = { ...patch, ...pending.current }
      setProblem(`El cambio no quedó guardado: ${(error as Error).message}`)
      inFlight.current = false
      setSaving(false)
      return
    }
    inFlight.current = false
    setSaving(false)
    if (Object.keys(pending.current).length) void pump()
  }
  function update(patch: Partial<Preferences>) {
    pending.current = { ...pending.current, ...patch }
    void pump()
  }
  useEffect(() => {
    void window.viewrvDesktop.getZoomFactor().then(setZoom)
  }, [])
  const currentZoom = zoom ?? confirmed?.ui_zoom ?? 1
  return (
    <section className={styles.info}>
      <h2>Ajustes</h2>
      {limitations
        ?.filter((item) => item.section === 'preferences')
        .map((item, index) => (
          <p key={index} role="alert">
            {item.message}
          </p>
        ))}
      <div className={styles.form}>
        <label className={styles.preferenceCard}>
          <span>
            <UserRound size={18} /> Autor predeterminado
          </span>
          <input
            value={author}
            onChange={(event) => setAuthor(event.target.value)}
            onBlur={() => update({ default_author: author.trim() || null })}
          />
        </label>
        <label className={styles.preferenceCard}>
          <span>
            <NotebookPen size={18} /> Registrar ensayos por defecto
          </span>
          <input
            type="checkbox"
            checked={record}
            onChange={(event) => {
              setRecord(event.target.checked)
              update({ record_by_default: event.target.checked })
            }}
          />
        </label>
        <label className={styles.preferenceCard}>
          <span>
            <ZoomIn size={18} /> Escala de la interfaz
          </span>
          <select
            aria-label="Escala de la interfaz"
            value={currentZoom}
            onChange={(event) => {
              const factor = Number(event.target.value)
              setZoom(factor)
              void window.viewrvDesktop
                .setZoomFactor(factor)
                .catch((error) => setProblem(String(error)))
              update({ ui_zoom: factor })
            }}
          >
            {[0.5, 0.75, 1, 1.25, 1.5, 1.75, 2].map((factor) => (
              <option key={factor} value={factor}>
                {factor * 100}%
              </option>
            ))}
          </select>
        </label>
        <label className={styles.preferenceCard}>
          <span>
            <Languages size={18} /> Idioma
          </span>
          <select
            aria-label="Idioma"
            value="es"
            disabled
            title="Español es el idioma disponible en esta entrega"
          >
            <option value="es">Español</option>
          </select>
        </label>
        {saving && <p role="status">Guardando preferencias…</p>}
        {problem && (
          <div role="alert">
            <p>{problem}</p>
            <button
              onClick={() => {
                void pump()
              }}
            >
              Reintentar guardado
            </button>
          </div>
        )}
        {!problem && !saving && (
          <p className={styles.preferenceNote}>
            Los cambios confirmados se conservan para la próxima apertura.
          </p>
        )}
      </div>
    </section>
  )
}
