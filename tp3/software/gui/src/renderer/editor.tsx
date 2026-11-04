import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from 'react'
import Editor, { type OnMount } from '@monaco-editor/react'
import * as monaco from 'monaco-editor/editor/editor.api.js'
import { DocumentSync } from './document-sync'
import { Check, Info } from 'lucide-react'
import { ownWorkId, request, useCore } from './core-client'
import type { LatchName } from '../shared/contracts'
import { selectedSession } from './ide-workflow'
import { openView, reportError } from './ide-state'
import { emptyInspection, latchComponents, pickComponent, useInspection } from './inspection'
import { followOccurrence, stopFollowing } from './inspection'
import { SourceFollowActions } from './source-follow'
import { useExampleReference } from './example-guide'
import * as styles from './theme.css'
import { pinCompletionDetails } from './monaco-completion'
import { useSourceDecorations } from './source-decorations'
import { BreakpointActions } from './breakpoint-actions'
import { useBreakpointPosition } from './breakpoint-position'

const models = new Map<string, { model: monaco.editor.ITextModel; dispose: () => void }>()
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
function ensureModel(document: DocumentSync): monaco.editor.ITextModel {
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
export function ProgramEditor({
  document,
  onFocus,
  groupId,
}: {
  document: DocumentSync
  onFocus?: () => void
  groupId?: string
}) {
  const state = useSyncExternalStore(document.subscribe, document.snapshot)
  const assembling = useCore((core) =>
    core.live.state?.assemblies.find((item) => item.program_id === state.program.program_id),
  )
  const closingApp = useCore((core) => core.closing)
  const core = useCore((state) => state.live.state)
  const synchronized = useCore((state) => state.synchronized)
  const session = selectedSession(core ?? null, ownWorkId())
  const inspection = useInspection(
    (state) => state.items[session?.session_id ?? ''] ?? emptyInspection,
  )
  const own =
    core?.works.find((work) => work.session_id === session?.session_id)?.work_id === ownWorkId()
  const belongs =
    session?.program_id === state.program.program_id &&
    session.source_version === state.capture.source_version
  const [breakLine, setBreakLine] = useState<number | null>(null)
  const breakpointPopup = useRef<HTMLDivElement>(null)
  const [pickLine, setPickLine] = useState<number | null>(null)
  const [pickMode, setPickMode] = useState<'inspect' | 'follow'>('inspect')
  const appearancePopup = useRef<HTMLDivElement>(null)
  const [mounted, setMounted] = useState(0)
  const breakpointLines = useRef(new Set<number>())
  breakpointLines.current = new Set(session?.breakpoints.map((item) => item.line) ?? [])
  const { reference: example, error: exampleError } = useExampleReference(
    state.capture.source_text,
    state.program.example_id,
  )
  const focusCallback = useRef(onFocus)
  focusCallback.current = onFocus
  const editor = useRef<monaco.editor.IStandaloneCodeEditor | null>(null)
  const [overlays] = useState(() => {
    const node = window.document.createElement('div')
    node.className = 'monaco-editor vs viewrv-editor-overlays'
    return node
  })
  useEffect(() => {
    window.document.body.appendChild(overlays)
    return () => overlays.remove()
  }, [overlays])
  const model = ensureModel(document)
  const canManageBreakpoints =
    !!belongs && !!session?.debug_open && !!own && synchronized && !closingApp && !state.closing
  const breakpointAccess = useRef(false)
  breakpointAccess.current = canManageBreakpoints
  const dismissBreakpoint = useCallback(() => setBreakLine(null), [])
  useBreakpointPosition(
    mounted ? editor.current : null,
    canManageBreakpoints ? breakLine : null,
    breakpointPopup,
    dismissBreakpoint,
  )
  const canFollow =
    !!belongs &&
    !!session?.debug_open &&
    session.mode === 'debug' &&
    session.execution_status !== 'unknown' &&
    session.outcome?.interruption_reason !== 'communication_failure' &&
    synchronized &&
    !closingApp &&
    !state.closing
  const locations = belongs
    ? (session?.last_observation?.interpretation?.instruction_locations ?? [])
    : []
  const followLines = canFollow
    ? [...new Set(locations.flatMap((row) => (row.line ? [row.line] : [])))].sort((a, b) => a - b)
    : []
  const activeLine =
    inspection.follow?.status === 'following'
      ? (locations.find((row) => row.pc === inspection.follow?.pc)?.line ?? null)
      : null
  useEffect(() => {
    if (pickLine === null) return
    const dismiss = (event: PointerEvent) => {
      if (event.target instanceof Node && !appearancePopup.current?.contains(event.target))
        setPickLine(null)
    }
    window.document.addEventListener('pointerdown', dismiss, true)
    return () => window.document.removeEventListener('pointerdown', dismiss, true)
  }, [pickLine])
  useEffect(() => {
    if (breakLine === null) return
    if (!canManageBreakpoints) {
      setBreakLine(null)
      return
    }
    const dismiss = (event: PointerEvent) => {
      if (event.target instanceof Node && !breakpointPopup.current?.contains(event.target))
        setBreakLine(null)
    }
    const blur = () => setBreakLine(null)
    window.document.addEventListener('pointerdown', dismiss, true)
    window.addEventListener('blur', blur)
    return () => {
      window.document.removeEventListener('pointerdown', dismiss, true)
      window.removeEventListener('blur', blur)
    }
  }, [breakLine, canManageBreakpoints])
  const activeDiagnostic =
    assembling?.source_version === state.capture.source_version &&
    assembling.error?.code === 'ASSEMBLY_SOURCE_ERROR'
      ? assembling.error
      : null
  useEffect(() => {
    const line = activeDiagnostic?.details?.line
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
              message: activeDiagnostic.message,
            },
          ]
        : [],
    )
    if (!editor.current) return
    const decoration = editor.current.createDecorationsCollection(
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
    editor.current.changeViewZones((accessor) => {
      const content = window.document.createElement('div')
      content.className = styles.diagnostic
      content.textContent = activeDiagnostic.message
      content.setAttribute('role', 'alert')
      zone = accessor.addZone({ afterLineNumber: line, heightInLines: 2, domNode: content })
    })
    return () => {
      decoration.clear()
      editor.current?.changeViewZones((accessor) => accessor.removeZone(zone))
    }
  }, [model, activeDiagnostic, mounted])
  useSourceDecorations({
    instance: mounted ? editor.current : null,
    model,
    session,
    belongs: !!belongs,
    inspection,
    canManageBreakpoints,
  })
  const mount: OnMount = (instance) => {
    editor.current = instance
    instance.setModel(model)
    setMounted((value) => value + 1)
    const id = state.program.program_id
    if (!views.has(id)) views.set(id, new Set())
    views.get(id)!.add(instance)
    if (focusIntent === id) focusProgramEditor(id)
    instance.onDidFocusEditorText(() => {
      focusedEditor = instance
      focusCallback.current?.()
    })
    const hovered = instance.createDecorationsCollection()
    let hoverLine: number | null = null
    instance.onMouseMove((event) => {
      const buttonLine = Number(
        event.target.element?.closest<HTMLElement>('[data-breakpoint-line]')?.dataset
          .breakpointLine,
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
                    breakpointAccess.current &&
                    !breakpointLines.current.has(line) &&
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
        breakpointAccess.current
      ) {
        setPickLine(null)
        setBreakLine(event.target.position.lineNumber)
      }
      if (event.target.position && event.target.element?.closest('.viewrv-stage-badge')) {
        setBreakLine(null)
        setPickMode('inspect')
        setPickLine(event.target.position.lineNumber)
      }
    })
    instance.addAction({
      id: 'viewrv.source.appearances',
      label: 'Apariciones de la instrucción',
      keybindings: [monaco.KeyMod.CtrlCmd | monaco.KeyMod.Alt | monaco.KeyCode.F9],
      contextMenuGroupId: 'navigation',
      contextMenuOrder: 2,
      run: (target) => {
        setBreakLine(null)
        setPickMode('inspect')
        setPickLine(target.getPosition()?.lineNumber ?? 1)
      },
    })
    instance.addAction({
      id: 'viewrv.source.breakpoints',
      label: 'Breakpoints…',
      keybindings: [monaco.KeyCode.F9],
      contextMenuGroupId: 'navigation',
      contextMenuOrder: 3,
      run: (target) => {
        if (breakpointAccess.current) {
          setPickLine(null)
          setBreakLine(target.getPosition()?.lineNumber ?? 1)
        }
      },
    })
    instance.onDidDispose(() => {
      if (focusedEditor === instance) focusedEditor = null
      views.get(id)?.delete(instance)
      if (!views.get(id)?.size) views.delete(id)
    })
  }
  async function toggleBreakpoint(latch: LatchName) {
    if (!breakLine || !session || !canManageBreakpoints) return
    const exists = session.breakpoints.some(
      (item) => item.line === breakLine && item.latch === latch,
    )
    try {
      await request('POST', `debug/breakpoint/${exists ? 'remove' : 'add'}`, {
        line: breakLine,
        latch,
      })
      setBreakLine(null)
    } catch (error) {
      reportError(error)
    }
  }
  function startFollowing(latch: LatchName) {
    if (!session || !canFollow) return
    void followOccurrence(session, latch)
    openView({
      component: 'diagram',
      session_id: session.session_id,
      program_id: session.program_id,
      placement: 'right',
    })
    setPickLine(null)
  }
  function followLine(line: number) {
    const candidates = locations.filter((row) => row.line === line)
    if (!canFollow || !candidates.length || !session) return
    if (candidates.length > 1) {
      setBreakLine(null)
      setPickMode('follow')
      setPickLine(line)
    } else if (activeLine === line) stopFollowing(session.session_id)
    else startFollowing(candidates[0].latch)
  }
  return (
    <div className={styles.editor}>
      {(state.missing || state.problem) && (
        <div
          className={styles.notice}
          style={{ display: 'flex', alignItems: 'center', gap: 8, minHeight: 32 }}
        >
          {state.missing ? 'Borrador local sin confirmar en la nueva instancia · ' : ''}
          {state.problem && <span role="alert">{state.problem.message} · </span>}
          {state.problem && (
            <button
              onClick={() => {
                void document.retry()
              }}
            >
              Reintentar actualización
            </button>
          )}
        </div>
      )}
      {exampleError && <p role="alert">{exampleError}</p>}

      <Editor
        path={model.uri.toString()}
        defaultLanguage="viewrv-assembly"
        keepCurrentModel
        saveViewState
        onMount={mount}
        options={{
          readOnly: state.closing || closingApp || state.program.edit_protected,
          renderValidationDecorations: 'off',
          minimap: { enabled: false },
          fontFamily: 'IBM Plex Mono',
          fontSize: 14,
          padding: { bottom: 42 },
          glyphMargin: true,
          wordWrap: 'on',
          tabSize: 4,
          insertSpaces: true,
          detectIndentation: false,
          formatOnType: true,
          formatOnPaste: true,
          wrappingIndent: 'same',
          automaticLayout: true,
          fixedOverflowWidgets: true,
          overflowWidgetsDomNode: overlays,
          suggestFontSize: 13,
          suggestLineHeight: 25,
          renderLineHighlight: 'all',
          renderLineHighlightOnlyWhenFocus: false,
          quickSuggestions: { other: true, comments: false, strings: false },
          wordBasedSuggestions: 'off',
        }}
      />
      <SourceFollowActions
        editor={mounted ? editor.current : null}
        lines={followLines}
        multipleLines={followLines.filter(
          (line) => locations.filter((row) => row.line === line).length > 1,
        )}
        activeLine={activeLine}
        onChoose={followLine}
      />
      <BreakpointActions
        editor={mounted ? editor.current : null}
        enabled={canManageBreakpoints}
        openLine={breakLine}
        onChoose={(line) => {
          setPickLine(null)
          setBreakLine(line)
        }}
      />
      {example && (
        <button
          className={styles.exampleInfoButton}
          aria-label="Acerca del ejemplo"
          title="Acerca del ejemplo"
          onClick={() =>
            openView({
              component: 'example-info',
              program_id: state.program.program_id,
              group_id: groupId,
            })
          }
        >
          <Info size={17} />
        </button>
      )}
      {assembling?.status === 'ready' &&
        assembling.source_version !== state.capture.source_version && (
          <span
            className={styles.editorHint}
            title="El resultado corresponde a una revisión anterior; el texto actual se conserva."
            aria-label="El resultado corresponde a una revisión anterior; el texto actual se conserva."
          >
            <Info size={13} />
            Ensamblado anterior
          </span>
        )}
      {pickLine !== null && session && (
        <div
          ref={appearancePopup}
          className={styles.breakpointOptions}
          role="dialog"
          aria-label={`Apariciones de la línea ${pickLine}`}
          onKeyDown={(event) => {
            if (event.key === 'Escape') {
              event.stopPropagation()
              setPickLine(null)
              editor.current?.focus()
            }
          }}
        >
          {locations
            .filter((row) => row.line === pickLine)
            .map((row, index) => (
              <button
                autoFocus={index === 0}
                key={row.latch}
                className={styles.breakpointOption}
                aria-label={`${pickMode === 'follow' ? 'Seguir en' : 'Seleccionar'} ${row.latch}`}
                onClick={() => {
                  if (pickMode === 'follow') startFollowing(row.latch)
                  else {
                    pickComponent(session.session_id, latchComponents[row.latch])
                    setPickLine(null)
                    editor.current?.focus()
                  }
                }}
              >
                <strong>{row.latch}</strong>
                <span>{pickMode === 'follow' ? 'Seguir aparición' : 'Seleccionar'}</span>
              </button>
            ))}
          {!locations.some((row) => row.line === pickLine) && (
            <p className={styles.muted}>Sin apariciones recibidas en esta línea.</p>
          )}
        </div>
      )}
      {breakLine !== null && canManageBreakpoints && session && (
        <div
          ref={breakpointPopup}
          className={`${styles.breakpointOptions} ${styles.anchoredBreakpoint}`}
          role="dialog"
          aria-label={`Breakpoint de la línea ${breakLine}`}
          onKeyDown={(event) => {
            if (event.key === 'Escape') {
              event.preventDefault()
              event.stopPropagation()
              setBreakLine(null)
              editor.current?.focus()
              return
            }
            if (['ArrowDown', 'ArrowUp', 'Home', 'End'].includes(event.key)) {
              event.preventDefault()
              const options = Array.from(event.currentTarget.querySelectorAll('button'))
              const current = options.indexOf(window.document.activeElement as HTMLButtonElement)
              options[
                event.key === 'Home'
                  ? 0
                  : event.key === 'End'
                    ? options.length - 1
                    : (current + (event.key === 'ArrowDown' ? 1 : -1) + options.length) %
                      options.length
              ]?.focus()
            }
          }}
          onBlur={(event) => {
            if (
              event.relatedTarget instanceof Node &&
              !event.currentTarget.contains(event.relatedTarget)
            )
              setBreakLine(null)
          }}
        >
          {(['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB'] as LatchName[]).map((latch, index) => {
            const active = session.breakpoints.some(
              (item) => item.line === breakLine && item.latch === latch,
            )
            return (
              <button
                autoFocus={index === 0}
                key={latch}
                className={styles.breakpointChoice}
                aria-label={`${latch} · entrada a ${['ID', 'EX', 'MEM', 'WB'][index]}`}
                aria-pressed={active}
                onClick={() => {
                  void toggleBreakpoint(latch)
                }}
              >
                <strong>{latch}</strong>
                <span>Entrada a {['ID', 'EX', 'MEM', 'WB'][index]}</span>
                <Check
                  size={16}
                  aria-hidden="true"
                  style={{ visibility: active ? 'visible' : 'hidden' }}
                />
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
