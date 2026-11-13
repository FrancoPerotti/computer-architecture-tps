import { useEffect, useRef } from 'react'
import * as monaco from 'monaco-editor/editor/editor.api.js'
import type { LatchName, SessionView } from '../shared/contracts'
import type { Inspection } from './inspection'

/** Source-only presentation; never sends processor or breakpoint commands. */
export function useSourceDecorations({
  instance,
  model,
  session,
  belongs,
  inspection,
  canManageBreakpoints,
}: {
  instance: monaco.editor.IStandaloneCodeEditor | null
  model: monaco.editor.ITextModel
  session: SessionView | null
  belongs: boolean
  inspection: Inspection
  canManageBreakpoints: boolean
}) {
  const selectionCentre = useRef(0)
  useEffect(() => {
    if (!instance) return
    const root = instance.getDomNode()
    if (root) root.dataset.breakpointsEnabled = String(canManageBreakpoints)
    if (!belongs || !session?.debug_open) {
      instance.updateOptions({ lineNumbersMinChars: 3 })
      return
    }
    const locations = session?.last_observation?.interpretation?.instruction_locations ?? []
    const marks: monaco.editor.IModelDeltaDecoration[] = []
    const instructionLines = canManageBreakpoints
      ? model.getLinesContent().flatMap((text, index) => {
          const code = text.split('#')[0].trim()
          return code && !code.endsWith(':') ? [index + 1] : []
        })
      : []
    const lines = new Set([
      ...instructionLines,
      ...locations.map((item) => item.line),
      ...session.breakpoints.map((item) => item.line),
    ])
    const latchOrder: LatchName[] = ['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB']
    const measure = window.document.createElement('canvas').getContext('2d')!
    measure.font = '500 10px "IBM Plex Mono"'
    const targetWidth = Math.max(
      0,
      ...[...lines].map(
        (line) =>
          measure.measureText(
            latchOrder
              .filter((latch) =>
                session.breakpoints.some((row) => row.line === line && row.latch === latch),
              )
              .join(' · '),
          ).width,
      ),
    )
    const digitWidth = instance.getOption(monaco.editor.EditorOption.fontInfo).maxDigitWidth
    instance.updateOptions({
      lineNumbersMinChars: targetWidth
        ? Math.ceil((targetWidth + 8) / digitWidth) + String(model.getLineCount()).length
        : 3,
    })
    for (const line of lines) {
      if (!line || line > model.getLineCount()) continue
      const stages = locations.filter((item) => item.line === line).map((item) => item.latch)
      const breakpoints = session.breakpoints.filter((item) => item.line === line)
      const targetMask = latchOrder.reduce(
        (mask, latch, index) =>
          mask | (breakpoints.some((row) => row.latch === latch) ? 1 << index : 0),
        0,
      )
      const highlighted =
        inspection.latch &&
        (!inspection.follow || inspection.follow.status === 'following') &&
        stages.includes(inspection.latch)
          ? 'viewrv-selected-occurrence-line'
          : stages.length
            ? 'viewrv-stage-line'
            : undefined
      marks.push({
        range: new monaco.Range(line, 1, line, model.getLineMaxColumn(line)),
        options: {
          isWholeLine: true,
          lineNumberClassName: targetMask ? `viewrv-breakpoint-targets-${targetMask}` : undefined,
          className: highlighted,
          marginClassName: highlighted ? `${highlighted}-margin` : undefined,
          glyphMarginClassName: breakpoints.length
            ? 'viewrv-breakpoint'
            : canManageBreakpoints
              ? 'viewrv-breakpoint-slot'
              : undefined,
          glyphMargin: { position: monaco.editor.GlyphMarginLane.Left },
          glyphMarginHoverMessage: {
            value:
              breakpoints.map((item) => `Breakpoint ${item.latch}`).join(' · ') ||
              'Agregar breakpoint',
          },
          after: stages.length
            ? {
                content: '  ' + stages.join(' · '),
                inlineClassName: 'viewrv-stage-badge',
                inlineClassNameAffectsLetterSpacing: true,
              }
            : undefined,
        },
      })
      if (canManageBreakpoints && instructionLines.includes(line))
        marks.push({
          range: new monaco.Range(line, 1, line, 1),
          options: {
            glyphMarginClassName: 'viewrv-breakpoint-menu-lane',
            glyphMargin: { position: monaco.editor.GlyphMarginLane.Right, persistLane: true },
          },
        })
    }
    const decoration = instance.createDecorationsCollection(marks)
    return () => decoration.clear()
  }, [
    session,
    belongs,
    model,
    instance,
    inspection.latch,
    inspection.follow?.status,
    canManageBreakpoints,
  ])
  useEffect(() => {
    if (
      !instance ||
      !belongs ||
      !session?.debug_open ||
      !inspection.latch ||
      selectionCentre.current === inspection.centre
    )
      return
    const line = session?.last_observation?.interpretation?.instruction_locations.find(
      (row) => row.latch === inspection.latch,
    )?.line
    if (line) {
      instance.revealLineInCenterIfOutsideViewport(line)
      selectionCentre.current = inspection.centre
    }
  }, [
    inspection.centre,
    inspection.latch,
    belongs,
    instance,
    session?.last_observation?.step_index,
  ])
}
