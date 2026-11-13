import { useLayoutEffect, useState } from 'react'
import { createPortal } from 'react-dom'
import { Route, Unlink } from 'lucide-react'
import * as monaco from 'monaco-editor/editor/editor.api.js'
import * as styles from './theme.css'

/** Native Monaco anchors keep each accessible action with its logical line,
 * including wrapped text, scrolling and split resizing. */
export function SourceFollowActions({
  editor,
  lines,
  multipleLines,
  activeLine,
  onChoose,
}: {
  editor: monaco.editor.IStandaloneCodeEditor | null
  lines: number[]
  multipleLines: number[]
  activeLine: number | null
  onChoose(line: number): void
}) {
  const [anchors, setAnchors] = useState<
    { line: number; node: HTMLDivElement; widget: monaco.editor.IContentWidget }[]
  >([])
  const lineKey = lines.join(',')
  useLayoutEffect(() => {
    const model = editor?.getModel()
    if (!editor || !model) {
      setAnchors([])
      return
    }
    const entries = lines.map((line) => {
      const node = document.createElement('div')
      node.className = styles.sourceFollowAnchor
      const widget: monaco.editor.IContentWidget = {
        getId: () => `viewrv-follow-${line}`,
        getDomNode: () => node,
        beforeRender: () => ({ width: 30, height: 19 }),
        // Right advances the view column past all injected stage labels at the source EOL.
        getPosition: () => ({
          position: { lineNumber: line, column: model.getLineMaxColumn(line) },
          preference: [monaco.editor.ContentWidgetPositionPreference.EXACT],
          positionAffinity: monaco.editor.PositionAffinity.Right,
        }),
      }
      editor.addContentWidget(widget)
      return { line, node, widget }
    })
    setAnchors(entries)
    let frame = 0
    const reposition = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        for (const { widget } of entries) editor.layoutContentWidget(widget)
      })
    }
    const decorations = editor.onDidChangeModelDecorations(reposition)
    reposition()
    return () => {
      cancelAnimationFrame(frame)
      decorations.dispose()
      for (const { widget } of entries) editor.removeContentWidget(widget)
    }
  }, [editor, lineKey])
  useLayoutEffect(() => {
    if (editor) for (const { widget } of anchors) editor.layoutContentWidget(widget)
  }, [editor, anchors])
  return (
    <>
      {anchors.map(({ line, node }) => {
        const stop = activeLine === line && !multipleLines.includes(line)
        return createPortal(
          <button
            className={styles.sourceFollowButton}
            aria-label={`${stop ? 'Dejar de seguir' : 'Seguir'} instrucción de la línea ${line}`}
            title={
              multipleLines.includes(line)
                ? 'Elegir aparición para seguir'
                : stop
                  ? 'Dejar de seguir esta instrucción'
                  : 'Seguir esta instrucción'
            }
            aria-pressed={activeLine === line}
            onMouseDown={(event) => event.stopPropagation()}
            onClick={() => onChoose(line)}
          >
            {stop ? <Unlink size={14} /> : <Route size={14} />}
          </button>,
          node,
          String(line),
        )
      })}
    </>
  )
}
