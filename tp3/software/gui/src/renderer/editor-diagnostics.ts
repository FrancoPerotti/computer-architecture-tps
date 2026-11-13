import { useEffect } from 'react'
import * as monaco from 'monaco-editor/editor/editor.api.js'
import type { ApiError } from '../shared/contracts'
import * as styles from './theme.css'

export function useEditorDiagnostics(
  instance: monaco.editor.IStandaloneCodeEditor | null,
  model: monaco.editor.ITextModel,
  diagnostic: ApiError | null,
): void {
  useEffect(() => {
    const line = diagnostic?.details?.line
    monaco.editor.setModelMarkers(
      model,
      'viewrv',
      line
        ? [
            {
              severity: monaco.MarkerSeverity.Error,
              startLineNumber: line,
              endLineNumber: line,
              startColumn: 1,
              endColumn: model.getLineMaxColumn(Math.min(line, model.getLineCount())),
              message: diagnostic.message,
            },
          ]
        : [],
    )
    if (!instance) return
    const decoration = instance.createDecorationsCollection(
      line
        ? [
            {
              range: new monaco.Range(
                line,
                1,
                line,
                model.getLineMaxColumn(Math.min(line, model.getLineCount())),
              ),
              options: { inlineClassName: 'viewrv-source-error' },
            },
          ]
        : [],
    )
    if (!line) return () => decoration.clear()
    let zone: string
    instance.changeViewZones((accessor) => {
      const content = window.document.createElement('div')
      content.className = styles.diagnostic
      content.textContent = diagnostic.message
      content.setAttribute('role', 'alert')
      zone = accessor.addZone({ afterLineNumber: line, heightInLines: 2, domNode: content })
    })
    return () => {
      decoration.clear()
      instance?.changeViewZones((accessor) => accessor.removeZone(zone))
    }
  }, [model, diagnostic, instance])
}
