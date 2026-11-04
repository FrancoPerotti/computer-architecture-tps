import * as monaco from 'monaco-editor/editor/editor.api.js'
import { reportError } from './ide-state'

let focusedEditor: monaco.editor.IStandaloneCodeEditor | null = null
const views = new Map<string, Set<monaco.editor.IStandaloneCodeEditor>>()
let focusIntent: string | null = null
export function focusProgramEditor(id: string): void {
  focusIntent = id
  requestAnimationFrame(() => {
    const candidates = [...(views.get(id) ?? [])]
    if (focusedEditor && candidates.includes(focusedEditor)) candidates.unshift(focusedEditor)
    const target = candidates.find((editor) => {
      const node = editor.getDomNode()
      return (
        node && node.getBoundingClientRect().width > 0 && node.getBoundingClientRect().height > 0
      )
    })
    if (target && focusIntent === id) {
      focusIntent = null
      target.focus()
    }
  })
}
export function editorCommand(command: string, programId?: string | null): void {
  const actions: Record<string, string> = {
    undo: 'undo',
    redo: 'redo',
    cut: 'editor.action.clipboardCutAction',
    copy: 'editor.action.clipboardCopyAction',
    paste: 'editor.action.clipboardPasteAction',
    'select-all': 'editor.action.selectAll',
    find: 'actions.find',
    format: 'editor.action.formatDocument',
  }
  if (!actions[command]) return
  const candidates = programId ? [...(views.get(programId) ?? [])] : []
  const target =
    focusedEditor && (!programId || candidates.includes(focusedEditor))
      ? focusedEditor
      : candidates.find((editor) => !!editor.getDomNode()?.getBoundingClientRect().width)
  if (!target) return
  // Restore the editor after the menu's focus manager has finished.
  requestAnimationFrame(() => {
    if (!target.getDomNode()?.isConnected) return
    if (command === 'format' && target.getOption(monaco.editor.EditorOption.readOnly)) return
    target.focus()
    if (command === 'cut' || command === 'copy' || command === 'paste') {
      const model = target.getModel()
      if (!model) return
      if (command !== 'copy' && target.getOption(monaco.editor.EditorOption.readOnly)) return
      const version = model.getVersionId()
      if (command === 'paste') {
        void window.viewrvDesktop
          .editCommand('paste')
          .then((text) => {
            if (
              typeof text === 'string' &&
              target.getModel() === model &&
              !target.getOption(monaco.editor.EditorOption.readOnly)
            )
              target.trigger('menu', 'paste', { text })
          })
          .catch(reportError)
      } else {
        const selections = target.getSelections() ?? []
        const text = selections
          .map((selection) =>
            selection.isEmpty()
              ? model.getLineContent(selection.startLineNumber) + model.getEOL()
              : model.getValueInRange(selection),
          )
          .join(model.getEOL())
        void window.viewrvDesktop
          .editCommand(command, text)
          .then(() => {
            if (
              command === 'cut' &&
              target.getModel() === model &&
              model.getVersionId() === version &&
              !target.getOption(monaco.editor.EditorOption.readOnly)
            )
              target.trigger('menu', 'cut', null)
          })
          .catch(reportError)
      }
      return
    }
    if (command === 'select-all') {
      const model = target.getModel()
      if (model) target.setSelection(model.getFullModelRange())
      return
    }
    target.trigger('menu', actions[command], null)
  })
}
export async function formatProgramEditor(programId: string): Promise<void> {
  const candidates = [...(views.get(programId) ?? [])]
  const target =
    focusedEditor && candidates.includes(focusedEditor)
      ? focusedEditor
      : candidates.find((editor) => editor.getDomNode()?.isConnected)
  if (!target || target.getOption(monaco.editor.EditorOption.readOnly)) return
  await target.getAction('editor.action.formatDocument')?.run()
}

export function registerProgramEditor(
  id: string,
  instance: monaco.editor.IStandaloneCodeEditor,
  onFocus: () => void,
): void {
  if (!views.has(id)) views.set(id, new Set())
  views.get(id)!.add(instance)
  if (focusIntent === id) focusProgramEditor(id)
  instance.onDidFocusEditorText(() => {
    focusedEditor = instance
    onFocus()
  })
  instance.onDidDispose(() => {
    if (focusedEditor === instance) focusedEditor = null
    views.get(id)?.delete(instance)
    if (!views.get(id)?.size) views.delete(id)
  })
}
