import { useState } from 'react'
import { createRoot } from 'react-dom/client'
import { Workflow, Code2, Settings, Minus, Square, X, Plug, Unplug, FileCheck2 } from 'lucide-react'
import 'flexlayout-react/style/light.css'
import { cancelWindowClose, finish, ownWorkId, request, startCore, useCore } from './core-client'
import { documents, label, saveProgram, startDocuments, useDocuments } from './documents'
import { configureEditor } from './assembly-language'
import { PreferencesPanel } from './preferences'
import { Workbench } from './workbench'
import { BoardPanel } from './board'
import { MenuBar } from './menus'
import { openView, reportError, useWorkspace } from './ide-state'
import { Toasts } from './toasts'
import { Modal } from './modal'
import { Brand } from './brand'
import { FileStatus } from './file-status'
import { selectedSession } from './ide-workflow'
import * as styles from './theme.css'
import './host.css'

function CloseDialog() {
  const failure = useCore((state) => state.closeProblem)
  const [error, setError] = useState<string | null>(null)
  if (!failure) return null
  const failures = failure.error.details?.failures ?? []
  const affected = failures.length
    ? [...new Set(failures.map((item) => item.program_id))]
    : [...documents.values()]
        .filter((document) => document.snapshot().program.is_open)
        .map((document) => document.snapshot().program.program_id)
  return (
    <Modal
      label="Código pendiente de conservación"
      title="La aplicación permanece abierta"
      onCancel={cancelWindowClose}
    >
      <p>{failure.message}</p>
      {error && <p role="alert">{error}</p>}
      {failures.map((item, index) => (
        <p key={index}>
          {item.path}: {item.message}
        </p>
      ))}
      <button
        onClick={() => {
          void finish()
        }}
      >
        Reintentar cierre
      </button>
      <button
        onClick={() => {
          void (async () => {
            try {
              for (const id of affected) {
                const document = documents.get(id)
                if (document) await saveProgram(document, true)
              }
              setError(null)
            } catch (problem) {
              setError((problem as Error).message)
            }
          })()
        }}
      >
        Guardar en otro destino…
      </button>
      {affected.length > 0 && (
        <button
          onClick={() => {
            void finish(true)
          }}
        >
          Salir sin conservar
        </button>
      )}
      <button onClick={cancelWindowClose}>Cancelar</button>
    </Modal>
  )
}
function ConnectionDialog() {
  const open = useWorkspace((state) => state.connectionOpen)
  return (
    <Modal
      label="Conexión con la placa"
      open={open}
      persist
      onCancel={() => useWorkspace.setState({ connectionOpen: false })}
    >
      <BoardPanel embedded />
    </Modal>
  )
}
function App() {
  const section = useWorkspace((state) => state.section)
  const setSection = (section: 'viewer' | 'editor' | 'settings') =>
    useWorkspace.setState({ section })
  const focus = useWorkspace((state) => state.focus)
  useDocuments((state) => state.revision)
  const focused = focus ? documents.get(focus)?.snapshot() : null
  const live = useCore((state) => state.live.state)
  const warnings = useCore((state) => state.live.state?.limitations)
  const synchronized = useCore((state) => state.synchronized)
  const boardStatus = useCore((state) => state.live.state?.board.connection_status)
  const image = live?.loaded_image
  const loadedProgram = live?.programs.find((program) => program.program_id === image?.program_id)
  const owner = live?.works.find((work) => work.owns_board)
  const foreign = !!owner && owner.work_id !== ownWorkId()
  const session = selectedSession(live ?? null, ownWorkId())
  const statusDocument =
    focused ??
    (section === 'editor' && session ? documents.get(session.program_id)?.snapshot() : null) ??
    null
  return (
    <main className={styles.shell}>
      <header className={`${styles.header} window-drag`}>
        <Brand />
        <MenuBar />
        <span className={styles.windowTitle}>viewrv</span>
        {window.viewrvDesktop.previewDemo && (
          <span
            className={styles.previewBadge}
            role="status"
            title="Capturas predefinidas del ejemplo Sumar dos números. Podés avanzar, reiniciar y usar breakpoints; no ejecuta programas arbitrarios."
          >
            Demo visual · sin FPGA
          </span>
        )}
        <div style={{ flex: 1 }} />
        {warnings?.some((item) => item.section === 'preferences') && (
          <span role="alert">No se pudieron recuperar las preferencias. Revisá Ajustes.</span>
        )}
        <div className={styles.windowControls}>
          <button
            className={styles.iconButton}
            aria-label="Minimizar ventana"
            onClick={() => {
              void window.viewrvDesktop.windowControl('minimize')
            }}
          >
            <Minus size={16} />
          </button>
          <button
            className={styles.iconButton}
            aria-label="Maximizar o restaurar ventana"
            onClick={() => {
              void window.viewrvDesktop.windowControl('maximize')
            }}
          >
            <Square size={13} />
          </button>
          <button
            className={styles.iconButton}
            aria-label="Cerrar ventana"
            onClick={() => {
              void window.viewrvDesktop.requestWindowClose()
            }}
          >
            <X size={16} />
          </button>
        </div>
      </header>
      <div className={styles.content}>
        <nav aria-label="Navegación principal" className={styles.sidebar}>
          {[
            ['viewer', 'Visor interactivo', Workflow],
            ['editor', 'IDE', Code2],
            ['settings', 'Ajustes', Settings],
          ].map(([key, label, Icon]) => {
            const Component = Icon as typeof Workflow
            return (
              <button
                key={key as string}
                className={styles.navButton}
                aria-label={label as string}
                title={label as string}
                aria-pressed={section === key}
                onClick={() => setSection(key as 'viewer' | 'editor' | 'settings')}
              >
                <Component size={22} />
              </button>
            )
          })}
        </nav>
        <section className={`${styles.workspace} ${styles.appWorkspace}`}>
          <div
            aria-hidden={section !== 'viewer'}
            inert={section !== 'viewer'}
            style={{
              position: 'absolute',
              inset: 0,
              visibility: section === 'viewer' ? 'visible' : 'hidden',
            }}
          >
            <div className={styles.viewerSurface}>
              <iframe
                title="Visor interactivo del pipeline"
                className={styles.frame}
                sandbox="allow-scripts"
                src="viewrv://app/content/viewer/explore.html"
              />
            </div>
          </div>
          <div
            aria-hidden={section !== 'editor'}
            inert={section !== 'editor'}
            style={{
              position: 'absolute',
              inset: 0,
              display: section === 'editor' ? 'block' : 'none',
            }}
          >
            <Workbench />
          </div>
          {section === 'settings' && <PreferencesPanel />}
        </section>
      </div>
      <footer className={styles.status} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <span style={{ color: boardStatus === 'checked' ? '#24845c' : '#ba3348' }}>
          ●{' '}
          {synchronized
            ? boardStatus === 'checked'
              ? `FPGA conectada · ${live?.board.port}`
              : boardStatus === 'checking' || live?.board.recovery_pending
                ? 'Recuperando comunicación…'
                : 'FPGA desconectada'
            : 'Sin conexión con el core'}
        </span>
        <button
          className={styles.statusAction}
          aria-label={boardStatus === 'checked' ? 'Desconectar' : 'Conectar'}
          title={boardStatus === 'checked' ? 'Desconectar' : 'Conectar'}
          disabled={!synchronized || foreign}
          onClick={() => {
            if (boardStatus === 'checked')
              void request('POST', 'board/disconnect', {}).catch(reportError)
            else openView({ component: 'connection' })
          }}
        >
          {boardStatus === 'checked' ? <Unplug size={15} /> : <Plug size={15} />}
        </button>
        <span className={styles.loadedImage}>
          {image?.status === 'loaded' ? (
            <>
              <FileCheck2 size={14} role="img" aria-label="Programa cargado en FPGA">
                <title>Programa cargado en FPGA</title>
              </FileCheck2>
              <span>{loadedProgram ? label(loadedProgram) : image.program_id?.slice(0, 8)}</span>
            </>
          ) : image?.status === 'unknown' ? (
            'Imagen en FPGA sin confirmar'
          ) : (
            'Sin programa cargado'
          )}
        </span>
        <FileStatus
          state={statusDocument}
          changedSinceLoad={
            !!statusDocument &&
            image?.program_id === statusDocument.program.program_id &&
            image.source_version !== statusDocument.capture.source_version
          }
        />
      </footer>
      <Toasts />
      <CloseDialog />
      <ConnectionDialog />
    </main>
  )
}
const root = createRoot(document.getElementById('root')!)
async function renderApplication() {
  try {
    await configureEditor()
    root.render(<App />)
  } catch (error) {
    root.render(
      <div className={styles.info}>
        <h2>No se pudo cargar el editor</h2>
        <p role="alert">{(error as Error).message}</p>
        <button
          onClick={() => {
            void renderApplication()
          }}
        >
          Reintentar
        </button>
        <button
          onClick={() => {
            void window.viewrvDesktop.requestWindowClose()
          }}
        >
          Cerrar aplicación
        </button>
      </div>,
    )
  }
}
startDocuments()
startCore()
void renderApplication()
