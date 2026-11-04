import { useEffect, useRef, useState } from 'react'
import { CoreFailure, ownWorkId, request, useCore } from './core-client'
import * as styles from './theme.css'
import { Modal } from './modal'
import { BookOpen, Cpu, Info, Plug, RefreshCw, Unplug, Upload } from 'lucide-react'

interface Candidate {
  id: string
  description: string | null
}
interface ConnectionResult {
  port: string
  reset_used: boolean
  device_id?: string
}

export function BoardPanel({ embedded = false }: { embedded?: boolean }) {
  const { live, synchronized, problem, closing } = useCore()
  const board = live.state?.board
  const owner = live.state?.works.find((work) => work.owns_board)
  const own = owner?.work_id === ownWorkId()
  const foreign = !!owner && !own
  const [devices, setDevices] = useState<Candidate[]>([])
  const [ports, setPorts] = useState<Candidate[]>([])
  const [device, setDevice] = useState('')
  const [port, setPort] = useState('')
  const [pending, setPending] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [failure, setFailure] = useState<string | null>(null)
  const [phases, setPhases] = useState<Record<string, string> | null>(null)
  const [guide, setGuide] = useState(false)
  const sequence = useRef(0)
  useEffect(() => {
    if (foreign) setNotice(null)
  }, [foreign])
  async function refresh() {
    setPending('refresh')
    setFailure(null)
    const results = await Promise.allSettled([
      request<Candidate[]>('GET', 'board/devices'),
      request<Candidate[]>('GET', 'board/ports'),
    ])
    if (results[0].status === 'fulfilled') setDevices(results[0].value)
    if (results[1].status === 'fulfilled') setPorts(results[1].value)
    const errors = results.filter(
      (result): result is PromiseRejectedResult => result.status === 'rejected',
    )
    if (errors.length)
      setFailure(errors.map((result) => String(result.reason.message ?? result.reason)).join(' · '))
    setPending(null)
  }
  async function action(name: string) {
    const chosen = ++sequence.current
    setPending(name)
    setNotice(null)
    setFailure(null)
    setPhases(null)
    try {
      const body =
        name === 'prepare'
          ? { ...(device ? { device_id: device } : {}), ...(port ? { port } : {}) }
          : name === 'connect' && port
            ? { port }
            : {}
      const result = await request<ConnectionResult>('POST', `board/${name}`, body)
      if (chosen !== sequence.current) return
      setNotice(
        name === 'prepare'
          ? `Programación confirmada. Comunicación UART comprobada en ${result.port}.${result.reset_used ? ' Se aplicó RESET.' : ''}`
          : name === 'connect'
            ? `Comunicación UART comprobada en ${result.port}.${result.reset_used ? ' Se aplicó RESET.' : ''}`
            : 'UART desconectado. El trabajo continúa abierto.',
      )
    } catch (error) {
      if (chosen !== sequence.current) return
      setFailure((error as Error).message)
      if (error instanceof CoreFailure && error.error.code === 'BOARD_PREPARATION_FAILED')
        setPhases(error.error.details as unknown as Record<string, string>)
    } finally {
      if (chosen === sequence.current) setPending(null)
    }
  }
  const blocked = !synchronized || closing || !!pending || foreign
  const connectionLabel = {
    closed: 'Sin conectar',
    checking: 'Comprobando',
    checked: 'Comunicación comprobada',
    unreliable: 'Comunicación no confiable',
  }[board?.connection_status ?? 'closed']
  return (
    <div className={embedded ? styles.boardPanel : `${styles.info} ${styles.boardPanel}`}>
      {!embedded && <h2>Conexión local</h2>}
      <div className={styles.boardHero}>
        <span className={styles.boardIcon}>
          <Cpu size={25} />
        </span>
        <div>
          <strong>Basys 3</strong>
          <p className={styles.muted}>
            {synchronized ? 'Conectado al core' : 'Esperando conexión con el core…'}
          </p>
        </div>
        <span
          className={styles.connectionBadge}
          data-connected={board?.connection_status === 'checked'}
        >
          {connectionLabel}
        </span>
      </div>
      {problem && (
        <p className={styles.boardFeedback} data-tone="error" role="alert">
          {problem}
        </p>
      )}
      <dl className={styles.boardSummary}>
        <div>
          <dt>Placa</dt>
          <dd>{connectionLabel}</dd>
        </div>
        <div>
          <dt>Preparación</dt>
          <dd>
            {board?.preparation_required
              ? 'Requiere programar el bitstream'
              : 'Programación confirmada en este core'}
          </dd>
        </div>
        <div>
          <dt>Puerto</dt>
          <dd>{board?.port ?? 'Sin seleccionar'}</dd>
        </div>
        <div>
          <dt>Puerto recordado</dt>
          <dd>{live.state?.preferences.last_serial_port ?? 'Ninguno'}</dd>
        </div>
      </dl>
      {board?.recovery_pending && (
        <p className={styles.boardFeedback} role="status">
          Queda pendiente recuperar la comunicación; reconectar conserva el límite de intentos de
          RESET.
        </p>
      )}
      {foreign && (
        <p className={styles.boardFeedback}>
          La placa está controlada por otro trabajo. Podés consultar su estado.
        </p>
      )}
      <section className={styles.boardDestinations} aria-label="Destinos de conexión">
        <div className={styles.boardSectionHeading}>
          <h3>Destinos de conexión</h3>
          <button
            className={styles.boardGuide}
            disabled={!synchronized || !!pending || closing}
            onClick={() => {
              void refresh()
            }}
          >
            <RefreshCw size={14} />
            Actualizar destinos
          </button>
        </div>
        <div className={styles.boardFields}>
          <label>
            Programador JTAG
            <select
              value={device}
              disabled={blocked}
              onChange={(event) => setDevice(event.target.value)}
            >
              <option value="">Automático si es inequívoco</option>
              {devices.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.description || item.id} ({item.id})
                </option>
              ))}
            </select>
          </label>
          <label>
            Puerto UART
            <select
              value={port}
              disabled={blocked}
              onChange={(event) => setPort(event.target.value)}
            >
              <option value="">Recordado o asociado inequívocamente</option>
              {ports.map((item) => (
                <option key={item.id} value={item.id}>
                  {item.description || item.id} ({item.id})
                </option>
              ))}
            </select>
          </label>
        </div>
      </section>
      <section className={styles.boardConnectionActions} aria-label="Acciones de conexión">
        <div className={styles.boardHelp}>
          <Info size={16} />
          <p>
            Preparar programa el procesador en la FPGA y después comprueba UART. La carga de tu
            programa Assembly es una operación posterior.
          </p>
        </div>
        <div className={styles.boardActions}>
          <button
            className={styles.primaryButton}
            disabled={blocked}
            onClick={() => {
              void action('prepare')
            }}
          >
            <Upload size={16} />
            Preparar Basys 3
          </button>
          <button
            className={styles.secondaryButton}
            disabled={blocked || board?.preparation_required}
            onClick={() => {
              void action('connect')
            }}
          >
            <Plug size={16} />
            Conectar UART
          </button>
          <button
            className={styles.secondaryButton}
            disabled={!own || closing || pending === 'disconnect'}
            onClick={() => {
              void action('disconnect')
            }}
          >
            <Unplug size={16} />
            Desconectar UART
          </button>
        </div>
        {pending && (
          <p className={styles.boardFeedback} role="status">
            {pending === 'refresh'
              ? 'Consultando destinos…'
              : pending === 'prepare'
                ? 'Preparando la placa y comprobando comunicación…'
                : 'Resolviendo la conexión…'}
          </p>
        )}
        {notice && (
          <p className={styles.boardFeedback} data-tone="success" role="status">
            {notice}
          </p>
        )}
        {failure && (
          <p className={styles.boardFeedback} data-tone="error" role="alert">
            {failure}
          </p>
        )}
        {phases && (
          <dl className={styles.boardSummary}>
            <div>
              <dt>Programación del bitstream</dt>
              <dd>
                {
                  {
                    not_attempted: 'No iniciada',
                    confirmed: 'Confirmada',
                    unconfirmed: 'Sin confirmar',
                  }[phases.programming_status]
                }
              </dd>
            </div>
            <div>
              <dt>RESET de UART</dt>
              <dd>
                {
                  {
                    not_attempted: 'No utilizado',
                    confirmed: 'Confirmado',
                    unconfirmed: 'Sin confirmar',
                  }[phases.reset_status]
                }
              </dd>
            </div>
            <div>
              <dt>Fase afectada</dt>
              <dd>{phases.phase === 'connection' ? 'Comprobación UART' : 'Programación'}</dd>
            </div>
          </dl>
        )}
        <button className={styles.boardGuide} onClick={() => setGuide(true)}>
          <BookOpen size={15} />
          Guía de conexión y permisos
        </button>
      </section>
      {guide && (
        <Modal
          label="Guía de conexión"
          title="Guía de conexión y permisos"
          onCancel={() => setGuide(false)}
        >
          <iframe
            title="Preparar el equipo y la Basys 3"
            sandbox=""
            src="viewrv://app/content/hardware-guide.html"
            style={{ width: '100%', height: '60vh', border: 0 }}
          />
          <button onClick={() => setGuide(false)}>Cerrar guía</button>
        </Modal>
      )}
    </div>
  )
}
