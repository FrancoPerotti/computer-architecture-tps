import { useEffect, useRef, useState } from 'react'
import { BookOpen, Cpu, FolderOpen, Plus, Scan, Copy } from 'lucide-react'
import { Actions, DockLocation, Layout, Model, TabNode, type Action } from 'flexlayout-react'
import { ownWorkId, useCore } from './core-client'
import { DocumentSync } from './document-sync'
import {
  closeProgram,
  createProgram,
  discardProgram,
  documents,
  label,
  modified,
  openExample,
  openProgram,
  recoverProgram,
  recoverable,
  saveProgram,
  setExampleTitles,
  useDocuments,
} from './documents'
import { ProgramEditor } from './editor'
import { disposeProgramModel } from './editor-models'
import { editorCommand, focusProgramEditor, formatProgramEditor } from './editor-commands'

import { ProcessorToolbar } from './processor-toolbar'
import { AssemblyResults, Results } from './results'
import { SessionDiagram } from './diagram'
import { InstructionCatalogPanel } from './instruction-catalog'
import { ExampleReferencePanel } from './example-guide'
import {
  launchProgram,
  notify,
  openView,
  reportError,
  translations,
  useWorkspace,
} from './ide-state'
import { actionReason, selectedSession } from './ide-workflow'
import { layoutText } from './layout-text'
import { ExamplePicker } from './example-picker'
import { RecoveryDialog } from './recovery-dialog'
import type { MenuCommand } from './menus'
import { exampleBank, type ExampleEntry } from './examples'
import * as styles from './theme.css'

const model = Model.fromJson({
  global: {
    tabSetEnableDeleteWhenEmpty: true,
    tabSetEnableClose: true,
    tabSetEnableCloseButton: false,
    tabEnableRename: false,
    tabEnableFloat: false,
    tabEnablePopout: false,
  },
  borders: [],
  layout: { type: 'row', children: [{ type: 'tabset', id: 'programs', children: [] }] },
})
function programNodes(id?: string): TabNode[] {
  const result: TabNode[] = []
  model.visitNodes((node) => {
    if (
      node instanceof TabNode &&
      node.getComponent() === 'program' &&
      (!id || node.getConfig()?.program_id === id)
    )
      result.push(node)
  })
  return result
}
function reveal(document: DocumentSync, focus = true) {
  const program = document.snapshot().program
  const existing = programNodes(program.program_id)[0]
  if (existing) model.doAction(Actions.selectTab(existing.getId()))
  else {
    const group = model.getActiveTabset() ?? model.getFirstTabSet()
    model.doAction(
      Actions.addTab(
        {
          type: 'tab',
          name: label(program),
          component: 'program',
          config: { program_id: program.program_id },
        },
        group?.getId() ?? 'programs',
        DockLocation.CENTER,
        -1,
        focus || !group?.getSelectedNode(),
      ),
    )
  }
  if (focus) focusProgramEditor(program.program_id)
}
export function Workbench() {
  const revision = useDocuments((state) => state.revision)
  const core = useCore((state) => state.live.state)
  const synchronized = useCore((state) => state.synchronized)
  const closing = useCore((state) => state.closing)
  const focus = useWorkspace((state) => state.focus)
  const setFocus = (focus: string | null) => useWorkspace.setState({ focus })
  const view = useWorkspace((state) => state.view)
  const launching = useWorkspace((state) => state.busy)
  const [examples, setExamples] = useState<ExampleEntry[]>([])
  const [chooseExample, setChooseExample] = useState(false)
  const [chooseRecovery, setChooseRecovery] = useState(false)
  const [, redraw] = useState(0)
  const session = selectedSession(core ?? null, ownWorkId())
  const previewOpened = useRef(false)
  useEffect(() => {
    if (!view) return
    let existing: TabNode | undefined
    model.visitNodes((node) => {
      if (
        node instanceof TabNode &&
        node.getComponent() === view.component &&
        (view.component !== 'example-info' || node.getConfig()?.program_id === view.program_id)
      )
        existing = node
    })
    const name = {
      debug: 'Estado del procesador',
      diagram: 'Pipeline',
      assembly: 'Vista ensamblada',
      catalog: 'Catálogo de instrucciones',
      connection: 'Conexión',
      'example-info': 'Acerca del ejemplo',
    }[view.component]
    if (existing) {
      model.doAction(Actions.updateNodeAttributes(existing.getId(), { config: view, name }))
      model.doAction(Actions.selectTab(existing.getId()))
    } else {
      const source = view.program_id ? programNodes(view.program_id)[0] : undefined
      const group =
        (view.group_id ? model.getNodeById(view.group_id) : undefined) ??
        source?.getParent() ??
        model.getActiveTabset() ??
        model.getFirstTabSet()
      model.doAction(
        Actions.addTab(
          { type: 'tab', name, component: view.component, config: view },
          group?.getId() ?? 'programs',
          view.component === 'debug' || view.placement === 'right'
            ? DockLocation.RIGHT
            : DockLocation.CENTER,
          -1,
          true,
        ),
      )
    }
    setFocus(null)
    redraw((value) => value + 1)
  }, [view?.id])
  useEffect(() => {
    void exampleBank()
      .then((bank) => {
        setExampleTitles(bank.catalog)
        setExamples(
          bank.catalog.filter((entry) => entry.memory_profiles.includes(bank.memoryProfile)),
        )
      })
      .catch(reportError)
  }, [])
  useEffect(() => {
    const open = [...documents.values()].filter((document) => document.snapshot().program.is_open)
    for (const document of open) {
      const p = document.snapshot().program
      if (!programNodes(p.program_id).length) reveal(document, false)
      const name = label(p) + (modified(document) ? ' ●' : '')
      for (const node of programNodes(p.program_id))
        if (node.getName() !== name)
          model.doAction(Actions.updateNodeAttributes(node.getId(), { name }))
    }
    for (const node of programNodes()) {
      const p = documents.get(node.getConfig().program_id)?.snapshot().program
      if (!p || !p.is_open) {
        const id = node.getConfig().program_id
        model.doAction(Actions.deleteTab(node.getId()))
        disposeProgramModel(id)
      }
    }
    const selected = (model.getActiveTabset() ?? model.getFirstTabSet())?.getSelectedNode()
    setFocus(selected?.getComponent() === 'program' ? selected.getConfig().program_id : null)
    redraw((value) => value + 1)
  }, [revision, core?.loaded_image])
  useEffect(() => {
    if (
      window.viewrvDesktop.previewDemo &&
      !previewOpened.current &&
      !launching &&
      session?.debug_open &&
      programNodes(session.program_id).length
    ) {
      previewOpened.current = true
      if (!useWorkspace.getState().view)
        openView({
          component: useWorkspace.getState().debugView,
          session_id: session.session_id,
          placement: 'right',
        })
    }
  }, [session?.session_id, session?.debug_open, revision, launching])
  async function run(operation: () => Promise<unknown>) {
    try {
      await operation()
    } catch (error) {
      reportError(error)
    }
  }
  const active = focus ? documents.get(focus) : undefined
  const state = active?.snapshot()
  const assembly = core?.assemblies.find((entry) => entry.program_id === focus)
  function addDocumentTab(component: string, name: string) {
    model.doAction(
      Actions.addTab(
        { type: 'tab', name, component },
        (model.getActiveTabset() ?? model.getFirstTabSet())?.getId() ?? 'programs',
        DockLocation.CENTER,
        -1,
        true,
      ),
    )
    setFocus(null)
    redraw((value) => value + 1)
  }
  function split(location: DockLocation) {
    const node = (model.getActiveTabset() ?? model.getFirstTabSet())?.getSelectedNode()
    if (!node) return
    model.doAction(
      Actions.addTab(
        {
          type: 'tab',
          name: node.getName(),
          component: node.getComponent(),
          config: node.getConfig(),
        },
        (model.getActiveTabset() ?? model.getFirstTabSet())!.getId(),
        location,
        -1,
        true,
      ),
    )
    redraw((value) => value + 1)
  }
  useEffect(() => {
    const listener = (event: Event) => {
      const command = (event as CustomEvent<MenuCommand>).detail
      if (closing) return
      if (command === 'connection') {
        openView({ component: 'connection' })
        return
      }
      if (command === 'recovery') {
        setChooseRecovery(true)
        return
      }
      useWorkspace.setState({ section: 'editor' })
      if (command === 'new') void run(async () => reveal(await createProgram()))
      else if (command === 'open')
        void run(async () => {
          const doc = await openProgram()
          if (doc) reveal(doc)
        })
      else if (command === 'example') setChooseExample(true)
      else if ((command === 'save' || command === 'save-as') && active)
        void run(async () => {
          await saveProgram(active, command === 'save-as', () =>
            formatProgramEditor(active.snapshot().program.program_id),
          )
          focusProgramEditor(active.snapshot().program.program_id)
        })
      else if (command === 'close') {
        const node = (model.getActiveTabset() ?? model.getFirstTabSet())?.getSelectedNode()
        if (node) {
          const next = action(Actions.deleteTab(node.getId()))
          if (next) model.doAction(next)
        }
      } else if (command === 'split-right' || command === 'split-bottom')
        split(command === 'split-right' ? DockLocation.RIGHT : DockLocation.BOTTOM)
      else if (command === 'catalog') addDocumentTab('catalog', 'Catálogo de instrucciones')
      else if (command === 'assembly') {
        const result = focus ? translations.get(focus) : null
        if (result) openView({ component: 'assembly', ...result })
        else notify('info', 'Ensamblá un programa para abrir su traducción')
      } else if (command === 'debug' || command === 'diagram') {
        if (session) openView({ component: command, session_id: session.session_id })
        else notify('info', 'No hay una sesión para observar')
      } else editorCommand(command, focus)
    }
    window.addEventListener('viewrv:menu', listener)
    return () => window.removeEventListener('viewrv:menu', listener)
  }, [focus, closing, session?.session_id])
  useEffect(() => {
    const keydown = (event: KeyboardEvent) => {
      if (
        !(event.ctrlKey || event.metaKey) ||
        closing ||
        useWorkspace.getState().section !== 'editor' ||
        document.querySelector('[role="dialog"][aria-modal="true"]')
      )
        return
      const key = event.key.toLowerCase()
      if (key === 'n') {
        event.preventDefault()
        void run(async () => reveal(await createProgram()))
      } else if (key === 'o') {
        event.preventDefault()
        void run(async () => {
          const doc = await openProgram()
          if (doc) reveal(doc)
        })
      } else if (key === 's' && active) {
        event.preventDefault()
        void run(async () => {
          await saveProgram(active, event.shiftKey, () =>
            formatProgramEditor(active.snapshot().program.program_id),
          )
        })
      } else if (event.shiftKey && event.key === 'Enter' && active) {
        event.preventDefault()
        event.stopPropagation()
        const current = useCore.getState(),
          workspace = useWorkspace.getState()
        const reason = actionReason('combined', {
          state: current.live.state,
          synchronized: current.synchronized,
          closing: current.closing,
          workId: ownWorkId(),
          capture: active.snapshot().capture,
          busy: !!workspace.busy,
          freshImage: current.freshImage,
        })
        if (reason) notify('info', reason)
        else void launchProgram(active, 'combined')
      }
    }
    window.addEventListener('keydown', keydown, true)
    return () => window.removeEventListener('keydown', keydown, true)
  }, [active, closing])
  function action(action: Action): Action | undefined {
    if (action.type === Actions.DELETE_TABSET) return undefined
    if (action.type === Actions.DELETE_TAB) {
      const node = model.getNodeById(action.data.node)
      if (node instanceof TabNode && node.getComponent() === 'program') {
        const id = node.getConfig().program_id as string
        if (programNodes(id).length === 1) {
          const document = documents.get(id)
          if (document)
            void run(async () => {
              await closeProgram(document)
              if (model.getNodeById(node.getId())) model.doAction(action)
              disposeProgramModel(id)
              redraw((value) => value + 1)
            })
          return undefined
        }
      }
    }
    return action
  }
  function factory(node: TabNode) {
    if (node.getComponent() === 'program') {
      const document = documents.get(node.getConfig().program_id)
      return document ? (
        <ProgramEditor
          document={document}
          groupId={node.getParent()?.getId()}
          onFocus={() => {
            setFocus(document.snapshot().program.program_id)
            const parent = node.getParent()
            if (parent) model.doAction(Actions.setActiveTabset(parent.getId()))
          }}
        />
      ) : null
    }
    if (node.getComponent() === 'debug')
      return <Results key={node.getConfig().session_id} sessionId={node.getConfig().session_id} />
    if (node.getComponent() === 'assembly')
      return (
        <AssemblyResults assembly={node.getConfig().assembly} capture={node.getConfig().capture} />
      )
    if (node.getComponent() === 'diagram')
      return (
        <SessionDiagram
          key={node.getConfig().session_id}
          sessionId={node.getConfig().session_id}
          onFocus={() => {
            setFocus(null)
            const parent = node.getParent()
            if (parent) model.doAction(Actions.setActiveTabset(parent.getId()))
          }}
        />
      )
    if (node.getComponent() === 'catalog') return <InstructionCatalogPanel />
    if (node.getComponent() === 'example-info') {
      const document = documents.get(node.getConfig().program_id)
      return document ? <ExampleReferencePanel document={document} session={session} /> : null
    }
    return null
  }
  let hasTabs = false
  model.visitNodes((node) => {
    if (node instanceof TabNode) hasTabs = true
  })
  const closed = core?.programs.filter((program) => !program.is_open && recoverable(program)) ?? []
  return (
    <div className={styles.ide}>
      <ProcessorToolbar document={active} />
      {core?.limitations
        .filter((item) => item.section === 'programs')
        .map((item, index) => (
          <div className={styles.error} role="alert" key={index}>
            {item.message}
          </div>
        ))}
      <div className={styles.workspace}>
        <Layout
          model={model}
          icons={{
            maximize: <Scan size={15} strokeWidth={1.6} aria-hidden="true" />,
            restore: <Copy size={15} strokeWidth={1.6} aria-hidden="true" />,
          }}
          factory={factory}
          i18nTranslator={layoutText}
          onAction={action}
          onRenderTab={(node, render) => {
            if (node.getComponent() !== 'program') return
            const document = documents.get(node.getConfig().program_id)
            const dirty = !!document && modified(document)
            render.content = (
              <span
                className={dirty ? styles.modifiedTab : undefined}
                data-modified={dirty}
                title={dirty ? 'Cambios sin guardar' : undefined}
              >
                {node.getName()}
              </span>
            )
          }}
          onModelChange={() => {
            const node = (model.getActiveTabset() ?? model.getFirstTabSet())?.getSelectedNode()
            setFocus(node?.getComponent() === 'program' ? node.getConfig().program_id : null)
            redraw((value) => value + 1)
          }}
        />
        {!hasTabs && (
          <div className={styles.welcome}>
            <Cpu size={34} />
            <h2>Tu espacio para programar</h2>
            <p>Escribí un programa o empezá con un ejemplo.</p>
            <button
              className={styles.welcomeAction}
              disabled={!synchronized || closing}
              onClick={() => setChooseExample(true)}
            >
              <BookOpen size={20} />
              <span>
                Abrir ejemplo<small>Elegí un programa del banco de ejemplos</small>
              </span>
            </button>
            <button
              className={styles.welcomeAction}
              disabled={!synchronized || closing}
              onClick={() => {
                void run(async () => {
                  const doc = await openProgram()
                  if (doc) reveal(doc)
                })
              }}
            >
              <FolderOpen size={20} />
              <span>
                Abrir programa<small>Buscá un archivo en tu computadora</small>
              </span>
            </button>
            <button
              className={styles.welcomeAction}
              disabled={!synchronized || closing}
              onClick={() => {
                void run(async () => reveal(await createProgram()))
              }}
            >
              <Plus size={20} />
              <span>
                Crear programa<small>Empezá con un archivo nuevo</small>
              </span>
            </button>
          </div>
        )}
      </div>
      <RecoveryDialog
        open={chooseRecovery}
        programs={closed}
        onClose={() => setChooseRecovery(false)}
        onRecover={(id) => {
          void run(async () => {
            reveal(await recoverProgram(id))
            setChooseRecovery(false)
            useWorkspace.setState({ section: 'editor' })
          })
        }}
        onDiscard={(id) => {
          void run(() => discardProgram(id))
        }}
      />
      <ExamplePicker
        open={chooseExample}
        examples={examples}
        onClose={() => setChooseExample(false)}
        onChoose={async (id) => {
          reveal(await openExample(id))
        }}
      />
    </div>
  )
}
