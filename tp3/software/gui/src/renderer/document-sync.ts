import type { ProgramView, SourceCapture } from '../shared/contracts'

export interface DocumentState {
  program: ProgramView
  capture: SourceCapture
  closing: boolean
  missing: boolean
  problem: Error | null
}
interface Receipt {
  capture: SourceCapture
  resolve: () => void
  reject: (error: Error) => void
}

/** Serializes source receipts, while actions keep their own immutable source capture. */
export class DocumentSync {
  private value: DocumentState
  private generation = 0
  private received: string
  private known = new Set<string>()
  private ordinary: SourceCapture | null = null
  private receipts: Receipt[] = []
  private running: Promise<void> | null = null
  private failed = false
  private listeners = new Set<() => void>()

  constructor(
    program: ProgramView,
    private update: (capture: SourceCapture) => Promise<ProgramView>,
    private changed: () => void = () => {},
  ) {
    const capture = this.fromProgram(program)
    this.value = { program, capture, closing: false, missing: false, problem: null }
    this.received = program.source_version
    this.known.add(program.source_version)
  }
  snapshot = (): DocumentState => this.value
  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }
  private emit(change: Partial<DocumentState>): void {
    this.value = { ...this.value, ...change }
    this.listeners.forEach((listener) => listener())
    this.changed()
  }
  private fromProgram(program: ProgramView): SourceCapture {
    return {
      program_id: program.program_id,
      source_version: program.source_version,
      source_text: program.source_text,
    }
  }
  edit(text: string, revision = crypto.randomUUID()): void {
    if (
      this.value.closing ||
      this.value.program.edit_protected ||
      text === this.value.capture.source_text
    )
      return
    const capture = { ...this.value.capture, source_version: revision, source_text: text }
    this.known.add(revision)
    this.ordinary = capture
    this.failed = false
    this.emit({ capture, problem: this.value.missing ? this.value.problem : null })
    if (!this.value.missing) this.pump()
  }
  apply(program: ProgramView): void {
    // Only an external revision may replace an idle local model. An old response
    // or SSE echo of one of our own revisions can never roll back local text.
    const mayAdopt = !this.running && !this.ordinary && !this.known.has(program.source_version)
    if (mayAdopt) {
      this.received = program.source_version
      this.known.add(program.source_version)
    }
    this.emit({ program, ...(mayAdopt ? { capture: this.fromProgram(program) } : {}) })
  }
  private pump(): void {
    if (this.running || this.failed || this.value.missing) return
    this.running = this.drain().finally(() => {
      this.running = null
      if (!this.failed && (this.ordinary || this.receipts.length)) this.pump()
    })
  }
  private async drain(): Promise<void> {
    while (!this.failed) {
      const generation = this.generation
      const receipt = this.receipts[0]
      const chosen = receipt?.capture ?? this.ordinary
      if (!chosen) return
      try {
        if (this.received !== chosen.source_version) {
          const acknowledged = await this.update({ ...chosen })
          if (generation !== this.generation) return
          if (
            acknowledged.program_id !== chosen.program_id ||
            acknowledged.source_version !== chosen.source_version
          )
            throw new Error('SOURCE_VERSION_MISMATCH: No se confirmó la revisión enviada.')
          this.received = chosen.source_version
        }
        if (this.ordinary?.source_version === chosen.source_version) this.ordinary = null
        if (receipt) {
          this.receipts.shift()
          receipt.resolve()
        }
      } catch (error) {
        if (generation !== this.generation) return
        this.failed = true
        this.emit({ problem: error as Error })
        const waiting = this.receipts.splice(0)
        waiting.forEach((item) => item.reject(error as Error))
      }
    }
  }
  async receive(capture: SourceCapture): Promise<void> {
    if (this.value.missing)
      throw this.value.problem ?? new Error('El programa no está disponible en el core.')
    this.failed = false
    await new Promise<void>((resolve, reject) => {
      this.receipts.push({ capture: { ...capture }, resolve, reject })
      this.pump()
    })
  }
  async action<T>(operation: (capture: SourceCapture) => Promise<T>): Promise<T> {
    const chosen = { ...this.value.capture }
    await this.receive(chosen)
    return operation(chosen)
  }
  async freezeAndReceive(): Promise<SourceCapture> {
    this.emit({ closing: true })
    const chosen = { ...this.value.capture }
    await this.receive(chosen)
    return chosen
  }
  unfreeze(): void {
    this.emit({ closing: false })
  }
  async close(operation: (capture: SourceCapture) => Promise<unknown>): Promise<void> {
    try {
      const chosen = await this.freezeAndReceive()
      await operation(chosen)
    } catch (error) {
      this.unfreeze()
      throw error
    }
  }
  resynchronize(program: ProgramView): void {
    this.generation++
    this.receipts
      .splice(0)
      .forEach((receipt) =>
        receipt.reject(
          new Error('La instancia del core cambió; la acción pendiente no se repite.'),
        ),
      )
    this.received = program.source_version
    this.failed = false
    if (program.source_text === this.value.capture.source_text) {
      this.ordinary = null
      this.known.add(program.source_version)
      this.emit({
        program,
        capture: this.fromProgram(program),
        missing: false,
        closing: false,
        problem: null,
      })
    } else {
      this.ordinary = { ...this.value.capture }
      this.emit({ program, missing: false, closing: false, problem: null })
      this.pump()
    }
  }
  markMissing(): void {
    this.generation++
    this.failed = true
    const error = new Error(
      'El core no conservó este borrador. Guardá una copia en otro destino para conservar el texto local.',
    )
    this.receipts.splice(0).forEach((receipt) => receipt.reject(error))
    this.emit({ missing: true, problem: error })
  }
  async retry(): Promise<void> {
    await this.receive({ ...this.value.capture })
  }
}
