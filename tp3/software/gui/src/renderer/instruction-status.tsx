import { useLayoutEffect, useRef } from 'react'
import { CircleCheck, CircleMinus, CircleX } from 'lucide-react'
import { feedbackAnimation } from './feedback-motion'
import * as styles from './theme.css'

export type InstructionStatusKind = 'valid' | 'empty' | 'fault'
const states = {
  valid: { icon: CircleCheck, label: 'Instrucción válida', className: styles.validIcon },
  empty: { icon: CircleMinus, label: 'Sin instrucción activa', className: styles.emptyIcon },
  fault: { icon: CircleX, label: 'Fallo de fetch', className: styles.invalidIcon },
}
export function InstructionStatus({ status }: { status: InstructionStatusKind }) {
  const node = useRef<HTMLSpanElement>(null)
  const last = useRef(status)
  useLayoutEffect(() => {
    const before = last.current
    last.current = status
    if (before === status || !node.current) return
    return feedbackAnimation(
      node.current,
      [
        { opacity: 0.2, transform: 'scale(.72) rotate(-10deg)' },
        { opacity: 1, transform: 'scale(1.06) rotate(0deg)', offset: 0.75 },
        { opacity: 1, transform: 'scale(1) rotate(0deg)' },
      ],
      { id: 'instruction-status', duration: 200, easing: 'cubic-bezier(0.2, 0, 0.38, 0.9)' },
    )
  }, [status])
  const { icon: Icon, label, className } = states[status]
  return (
    <span ref={node} className={styles.instructionStatus} data-status={status}>
      <Icon size={17} className={className} role="img" aria-label={label}>
        <title>{label}</title>
      </Icon>
    </span>
  )
}
