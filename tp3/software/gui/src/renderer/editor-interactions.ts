import * as monaco from 'monaco-editor/editor/editor.api.js'
import { pinCompletionDetails } from './monaco-completion'

type EditorInteractions = {
  canManageBreakpoints(): boolean
  hasBreakpoint(line: number): boolean
  chooseBreakpoint(line: number): void
  chooseAppearance(line: number): void
}

export function installEditorInteractions(
  instance: monaco.editor.IStandaloneCodeEditor,
  model: monaco.editor.ITextModel,
  actions: EditorInteractions,
): void {
  const hovered = instance.createDecorationsCollection()
  let hoverLine: number | null = null
  instance.onMouseMove((event) => {
    const buttonLine = Number(
      event.target.element?.closest<HTMLElement>('[data-breakpoint-line]')?.dataset.breakpointLine,
    )
    const line = event.target.position?.lineNumber ?? (buttonLine || null)
    if (line === hoverLine) return
    hoverLine = line
    hovered.set(
      line
        ? [
            {
              range: new monaco.Range(line, 1, line, model.getLineMaxColumn(line)),
              options: {
                isWholeLine: true,
                className: 'viewrv-hover-line',
                marginClassName: 'viewrv-hover-margin',
                lineNumberClassName: 'viewrv-hover-line-number',
                glyphMarginClassName:
                  actions.canManageBreakpoints() &&
                  !actions.hasBreakpoint(line) &&
                  !!model.getLineContent(line).split('#')[0].trim() &&
                  !model.getLineContent(line).split('#')[0].trim().endsWith(':')
                    ? 'viewrv-breakpoint-hover'
                    : undefined,
                glyphMargin: { position: monaco.editor.GlyphMarginLane.Left },
                zIndex: 0,
              },
            },
          ]
        : [],
    )
  })
  instance.onMouseLeave(() => {
    hoverLine = null
    hovered.clear()
  })
  instance.onDidScrollChange(() => {
    hoverLine = null
    hovered.clear()
  })
  const completionDetails = pinCompletionDetails(instance, [
    monaco.KeyMod.CtrlCmd | monaco.KeyCode.Space,
    monaco.KeyMod.WinCtrl | monaco.KeyCode.Space,
    monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyI,
  ])
  instance.onDidDispose(() => {
    completionDetails.dispose()
    hovered.clear()
  })

  instance.onMouseDown((event) => {
    if (
      event.target.type === monaco.editor.MouseTargetType.GUTTER_GLYPH_MARGIN &&
      !event.target.element?.closest('button') &&
      event.target.position &&
      actions.canManageBreakpoints()
    ) {
      actions.chooseBreakpoint(event.target.position.lineNumber)
    }
    if (event.target.position && event.target.element?.closest('.viewrv-stage-badge')) {
      actions.chooseAppearance(event.target.position.lineNumber)
    }
  })
  instance.addAction({
    id: 'viewrv.source.appearances',
    label: 'Apariciones de la instrucción',
    keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyMod.Alt | monaco.KeyCode.F9],
    contextMenuGroupId: 'navigation',
    contextMenuOrder: 2,
    run: (target) => {
      actions.chooseAppearance(target.getPosition()?.lineNumber ?? 1)
    },
  })
  instance.addAction({
    id: 'viewrv.source.breakpoints',
    label: 'Breakpoints…',
    keybindings: [monaco.KeyCode.F9],
    contextMenuGroupId: 'navigation',
    contextMenuOrder: 3,
    run: (target) => {
      if (actions.canManageBreakpoints()) {
        actions.chooseBreakpoint(target.getPosition()?.lineNumber ?? 1)
      }
    },
  })
}
