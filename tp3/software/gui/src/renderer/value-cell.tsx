import { useLayoutEffect, useRef, useState } from 'react'
import { feedbackAnimation } from './feedback-motion'
import { formatValue, type NumberFormat } from './ide-workflow'
import { colors } from './ui-tokens'
import * as styles from './theme.css'

// External global_state codes, in the order defined by the UART protocol.
const globalStateNames = [
  'NO_IMAGE',
  'LOADING',
  'PREPARING_READY',
  'READY',
  'RUNNING',
  'STEPPING',
  'HALT_DRAIN_AUTO',
  'HALT_DRAIN_STEP',
  'FAULT_DRAIN_AUTO',
  'FAULT_DRAIN_STEP',
  'FINISHED',
  'FAULT',
  'PREPARING_RUN',
  'PREPARING_STEP',
]
type ValueFormat = NumberFormat | 'state-name'

export function ValueCell({
  name,
  value,
  bits = 32,
  changed = false,
  previous,
}: {
  name: string
  value: number | string | boolean
  bits?: number
  changed?: boolean
  previous?: number | boolean | string | null
}) {
  const globalState = name === 'global_state'
  const [format, setFormat] = useState<ValueFormat>(
    globalState ? 'state-name' : name === 'cycle_count' ? 'unsigned' : 'hex',
  )
  const stateName = globalStateNames[Number(value)]
  const displayed =
    format === 'state-name'
      ? `${stateName ?? 'Estado desconocido'} (${formatValue(value, bits, 'hex')})`
      : formatValue(value, bits, format)
  const lastChanged = useRef(changed)
  const underlay = useRef<HTMLSpanElement>(null)
  const curtain = useRef<HTMLSpanElement>(null)
  useLayoutEffect(() => {
    const before = lastChanged.current
    lastChanged.current = changed
    const old = underlay.current,
      sweep = curtain.current
    if (before === changed || !old || !sweep) return
    old.style.backgroundColor = before ? colors.changed : colors.canvas
    sweep.style.backgroundColor = changed ? colors.changed : colors.canvas
    old.style.opacity = sweep.style.opacity = '1'
    return feedbackAnimation(
      sweep,
      [
        { transform: 'scaleX(0)', offset: 0 },
        { transform: 'scaleX(1)', offset: 0.74 },
        { transform: 'scaleX(.975)', offset: 0.88 },
        { transform: 'scaleX(1)', offset: 1 },
      ],
      { id: 'value-change', duration: 360, easing: 'cubic-bezier(0.2, 0, 0.38, 0.9)' },
      () => {
        old.style.opacity = sweep.style.opacity = '0'
      },
    )
  }, [changed])
  return (
    <div
      className={changed ? styles.changedCell : styles.valueCell}
      data-changed={changed}
      title={
        changed
          ? `Cambió respecto de la captura anterior: ${previous === null ? 'byte no observado antes' : String(previous)}`
          : undefined
      }
    >
      <span ref={underlay} className={styles.valueUnderlay} aria-hidden="true" />
      <span ref={curtain} className={styles.valueCurtain} aria-hidden="true" />
      <span className={styles.cellLabel}>
        {name}
        {changed && <span aria-label="Valor modificado"> · Δ</span>}
      </span>
      <code>{displayed}</code>
      <select
        aria-label={`Formato de ${name}`}
        value={format}
        onChange={(event) => setFormat(event.target.value as ValueFormat)}
      >
        {globalState && <option value="state-name">Nombre del estado</option>}
        <option value="hex">Hexadecimal</option>
        <option value="signed">Decimal con signo</option>
        <option value="unsigned">Decimal sin signo</option>
        <option value="binary">Binario</option>
      </select>
    </div>
  )
}
