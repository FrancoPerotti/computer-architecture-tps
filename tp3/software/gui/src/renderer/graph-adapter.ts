import type { Observation, ProcessorProfile } from '../shared/contracts'
import type { EducationalResources } from './educational-resources'
import { colors } from './theme.css'
import type { ConnectionSelection } from './inspection'
export interface GraphObservation {
  session_id: string
  program_id: string
  source_version: string
  observation: Observation | null
  stale: boolean
}
export class GraphViewerAdapter {
  private frame: HTMLIFrameElement | null = null
  private token = crypto.randomUUID()
  private ready = false
  private observation: GraphObservation | null = null
  private focus: string[] | null = null
  private selected: { block_id: string; centre: boolean } | null = null
  private resizeObserver: ResizeObserver | null = null
  constructor(
    private callbacks: {
      select(block: string): void
      error(message: string): void
      ready(): void
      activate?(): void
      connection?(value: ConnectionSelection): void
    },
  ) {}
  mount(
    container: HTMLElement,
    privateResources: EducationalResources,
    coreProfile: ProcessorProfile,
  ): void {
    if (this.frame) throw Error('El visor ya está montado.')
    if (
      ['profile_id', 'revision', 'memory_profile'].some(
        (key) =>
          coreProfile[key as keyof ProcessorProfile] !==
          privateResources.profile[key as keyof ProcessorProfile],
      )
    )
      throw Error('CORE_INCOMPATIBLE: el perfil del circuito no coincide con el core.')
    const frame = document.createElement('iframe')
    frame.title = 'Diagrama de la sesión'
    frame.setAttribute('sandbox', 'allow-scripts')
    frame.style.cssText = 'width:100%;height:100%;border:0;display:block'
    frame.src = `viewrv://app/content/viewer/session.html#${this.token}`
    this.frame = frame
    const listener = (event: MessageEvent) => {
      const value = event.data
      if (
        event.source !== frame.contentWindow ||
        value?.channel !== 'viewrv-graph-v1' ||
        value.token !== this.token
      )
        return
      if (value.kind === 'ready') {
        if (
          ['profile_id', 'revision', 'memory_profile'].some(
            (key) => value.profile?.[key] !== coreProfile[key as keyof ProcessorProfile],
          ) ||
          value.diagram_sha256 !== privateResources.profile.diagram_sha256 ||
          value.bindings_sha256 !== privateResources.profile.bindings_sha256 ||
          value.education_sha256 !== privateResources.education_sha256
        ) {
          this.callbacks.error(
            'El diagrama preparado no coincide con los recursos locales. Volvé a construir la aplicación.',
          )
          return
        }
        this.ready = true
        this.send({ kind: 'theme', theme: colors })
        if (this.observation) this.send({ kind: 'observation', context: this.observation })
        if (this.focus) this.setFocus(this.focus)
        if (this.selected) this.selectComponent(this.selected.block_id, this.selected.centre)
        this.callbacks.ready()
      } else if (
        value.kind === 'select' &&
        typeof value.block_id === 'string' &&
        Object.hasOwn(privateResources.bindings.blocks, value.block_id)
      )
        this.callbacks.select(value.block_id)
      else if (value.kind === 'activate') this.callbacks.activate?.()
      else if (
        value.kind === 'connection' &&
        ['id', 'name', 'route', 'description'].every(
          (key) =>
            typeof value.connection?.[key] === 'string' && value.connection[key].length < 20000,
        )
      )
        this.callbacks.connection?.(value.connection)
      else if (value.kind === 'error' && typeof value.message === 'string')
        this.callbacks.error(value.message)
    }
    this.removeListener = () => window.removeEventListener('message', listener)
    window.addEventListener('message', listener)
    this.resizeObserver = new ResizeObserver(() => this.resize())
    this.resizeObserver.observe(container)
    container.append(frame)
  }
  private removeListener: () => void = () => {}
  private send(value: unknown): void {
    if (this.ready)
      this.frame?.contentWindow?.postMessage(
        { channel: 'viewrv-graph-v1', token: this.token, ...(value as object) },
        '*',
      )
  }
  setObservation(context: GraphObservation): void {
    this.observation = context
    this.focus = null
    this.send({ kind: 'observation', context })
  }
  selectComponent(block_id: string, centre = false): void {
    this.selected = { block_id, centre }
    this.send({ kind: 'select', block_id, centre })
  }
  setFocus(blocks: string[]): void {
    this.focus = [...blocks]
    this.send({ kind: 'focus', blocks: this.focus })
  }
  resize(): void {
    this.send({ kind: 'resize' })
  }
  dispose(): void {
    this.send({ kind: 'dispose' })
    this.removeListener()
    this.resizeObserver?.disconnect()
    this.resizeObserver = null
    this.frame?.remove()
    this.frame = null
    this.ready = false
    this.observation = null
    this.focus = null
    this.selected = null
  }
}
