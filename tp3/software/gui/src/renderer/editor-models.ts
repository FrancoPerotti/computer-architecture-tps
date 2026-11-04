import * as monaco from 'monaco-editor/editor/editor.api.js'
import type { DocumentSync } from './document-sync'

const models = new Map<string, { model: monaco.editor.ITextModel; dispose: () => void }>()
export function ensureProgramModel(document: DocumentSync): monaco.editor.ITextModel {
  const id = document.snapshot().program.program_id
  const existing = models.get(id)
  if (existing) return existing.model
  const model = monaco.editor.createModel(
    document.snapshot().capture.source_text,
    'viewrv-assembly',
    monaco.Uri.parse(`viewrv://program/${id}.s`),
  )
  let applying = false
  const content = model.onDidChangeContent(() => {
    if (!applying) document.edit(model.getValue())
  })
  const unsubscribe = document.subscribe(() => {
    const current = document.snapshot().capture.source_text
    if (model.getValue() !== current) {
      applying = true
      model.setValue(current)
      applying = false
    }
  })
  models.set(id, {
    model,
    dispose: () => {
      unsubscribe()
      content.dispose()
      model.dispose()
    },
  })
  return model
}
export function disposeProgramModel(id: string): void {
  models.get(id)?.dispose()
  models.delete(id)
}
