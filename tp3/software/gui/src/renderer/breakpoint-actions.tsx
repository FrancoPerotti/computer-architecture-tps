import { useLayoutEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { ChevronDown } from 'lucide-react'
import * as monaco from 'monaco-editor/editor/editor.api.js'
import * as styles from './theme.css'

/** Monaco's margin is aria-hidden. A public overlay anchors accessible controls above it. */
export function BreakpointActions({
  editor,
  enabled,
  openLine,
  onChoose,
}: {
  editor: monaco.editor.IStandaloneCodeEditor | null
  enabled: boolean
  openLine: number | null
  onChoose(line: number): void
}) {
  const [view, setView] = useState<{
    node: HTMLElement
    rows: {
      line: number
      top: number
      left: number
      size: number
    }[]
  } | null>(null)
  useLayoutEffect(() => {
    const model = editor?.getModel()
    if (!editor || !model || !enabled) {
      setView(null)
      return
    }
    const node = document.createElement('div')
    node.className = styles.breakpointActions
    const widget: monaco.editor.IOverlayWidget = {
      getId: () => 'viewrv-breakpoint-actions',
      getDomNode: () => node,
      getPosition: () => null,
    }
    editor.addOverlayWidget(widget)
    let frame = 0
    const update = () => {
      const layout = editor.getLayoutInfo()
      const size = editor.getOption(monaco.editor.EditorOption.lineHeight)
      node.style.width = `${layout.glyphMarginLeft + layout.glyphMarginWidth}px`
      node.style.height = `${layout.height}px`
      const rows = model.getLinesContent().flatMap((text, index) => {
        const code = text.split('#')[0].trim(),
          line = index + 1
        if (!code || code.endsWith(':')) return []
        const position = editor.getScrolledVisiblePosition({ lineNumber: line, column: 1 })
        if (!position || position.top < 0 || position.top + size > layout.height) return []
        return [
          {
            line,
            top: position.top,
            left: layout.glyphMarginLeft + layout.glyphMarginWidth - size,
            size,
          },
        ]
      })
      setView({ node, rows })
    }
    const schedule = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(update)
    }
    const subscriptions = [
      editor.onDidLayoutChange(schedule),
      editor.onDidScrollChange(schedule),
      editor.onDidChangeConfiguration(schedule),
      model.onDidChangeContent(schedule),
    ]
    update()
    return () => {
      cancelAnimationFrame(frame)
      for (const subscription of subscriptions) subscription.dispose()
      editor.removeOverlayWidget(widget)
    }
  }, [editor, enabled])
  return (
    view &&
    createPortal(
      <>
        {view.rows.map(({ line, top, left, size }) => (
          <button
            key={line}
            data-breakpoint-line={line}
            className={styles.breakpointPicker}
            style={{ top, left, width: size, height: size }}
            aria-label={`Elegir registro del breakpoint de la línea ${line}`}
            title="Elegir registro del breakpoint"
            aria-haspopup="dialog"
            aria-expanded={openLine === line}
            onMouseDown={(event) => event.stopPropagation()}
            onClick={() => onChoose(line)}
          >
            <ChevronDown size={12} aria-hidden="true" />
          </button>
        ))}
      </>,
      view.node,
    )
  )
}
