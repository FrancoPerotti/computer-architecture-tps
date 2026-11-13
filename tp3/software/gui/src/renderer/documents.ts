import { create } from 'zustand'
import type { ProgramView } from '../shared/contracts'
import { DocumentSync } from './document-sync'
import { onBeforeClose, request, useCore } from './core-client'
import { exampleReference, type ExampleReference } from './examples'

export const documents = new Map<string, DocumentSync>()
const labels = new Map<string, string>()
const exampleLabels = new Map<string, ExampleReference>()
const exampleFiles = new Map<string, string>()
const pendingExampleLabels = new Set<string>()
let untitled = 0
export const useDocuments = create<{ revision: number }>(() => ({ revision: 0 }))
const changed = () => useDocuments.setState((state) => ({ revision: state.revision + 1 }))
export function label(program: ProgramView): string {
  if (program.source_path) return program.source_path.split(/[\\/]/).at(-1)!
  if (program.example_id)
    return (
      exampleLabels.get(program.example_id)?.source_path.split('/').at(-1) ??
      exampleFiles.get(program.example_id) ??
      `${program.example_id}.s`
    )
  if (!labels.has(program.program_id)) labels.set(program.program_id, `Sin título ${++untitled}`)
  return labels.get(program.program_id)!
}
export function setExampleTitles(entries: { example_id: string; source_path: string }[]): void {
  for (const entry of entries)
    exampleFiles.set(entry.example_id, entry.source_path.split('/').at(-1)!)
  changed()
}
export function recoverable(program: ProgramView): boolean {
  if (program.source_path) return program.saved_version !== program.source_version
  if (program.example_id) {
    const reference = exampleLabels.get(program.example_id)
    return !reference || reference.original !== program.source_text
  }
  return program.source_text.length > 0
}
export function modified(document: DocumentSync): boolean {
  const { program, capture } = document.snapshot()
  if (program.source_path) return program.saved_version !== capture.source_version
  if (program.example_id) {
    const reference = exampleLabels.get(program.example_id)
    return !!reference && reference.original !== capture.source_text
  }
  return capture.source_text.length > 0
}
function prepareExample(program: ProgramView): void {
  if (
    program.example_id &&
    !exampleLabels.has(program.example_id) &&
    !pendingExampleLabels.has(program.example_id)
  ) {
    const id = program.example_id
    pendingExampleLabels.add(id)
    void exampleReference(id)
      .then((reference) => {
        exampleLabels.set(id, reference)
        changed()
      })
      .catch(() => {})
      .finally(() => pendingExampleLabels.delete(id))
  }
}
export function acceptProgram(program: ProgramView): DocumentSync {
  prepareExample(program)
  let document = documents.get(program.program_id)
  if (!document) {
    document = new DocumentSync(
      program,
      (capture) => request<ProgramView>('POST', 'program/update', capture),
      changed,
    )
    documents.set(program.program_id, document)
    changed()
  } else document.apply(program)
  return document
}
export async function createProgram(): Promise<DocumentSync> {
  return acceptProgram(await request<ProgramView>('POST', 'program/create', {}))
}
export async function openProgram(): Promise<DocumentSync | null> {
  const path = await window.viewrvDesktop.chooseProgramFile()
  if (!path) return null
  const document = acceptProgram(
    await request<ProgramView>('POST', 'program/open', { source_path: path }),
  )
  document.unfreeze()
  return document
}
export async function openExample(exampleId: string): Promise<DocumentSync> {
  return acceptProgram(
    await request<ProgramView>('POST', 'program/open-example', { example_id: exampleId }),
  )
}
export async function recoverProgram(programId: string): Promise<DocumentSync> {
  const document = acceptProgram(
    await request<ProgramView>('POST', 'program/recover', { program_id: programId }),
  )
  document.unfreeze()
  return document
}
export async function saveProgram(
  document: DocumentSync,
  choosePath = false,
  beforeSave?: () => Promise<void>,
): Promise<void> {
  let path: string | null = null
  if (choosePath || !document.snapshot().program.source_path) {
    const name = label(document.snapshot().program)
    path = await window.viewrvDesktop.chooseSavePath(/\.[^./\\]+$/.test(name) ? name : name + '.s')
  }
  if ((choosePath || !document.snapshot().program.source_path) && !path) return
  // A canceled path chooser must not change the source or its undo history.
  await beforeSave?.()
  if (document.snapshot().missing) {
    const replacement = await createProgram()
    replacement.edit(document.snapshot().capture.source_text)
    await replacement.action((capture) =>
      request('POST', 'program/save', { ...capture, ...(path ? { source_path: path } : {}) }),
    )
    documents.delete(document.snapshot().program.program_id)
    changed()
    return
  }
  await document.action((capture) =>
    request('POST', 'program/save', { ...capture, ...(path ? { source_path: path } : {}) }),
  )
}
export async function closeProgram(document: DocumentSync): Promise<void> {
  await document.close((capture) => request('POST', 'program/close', capture))
}
export async function assembleProgram(document: DocumentSync): Promise<void> {
  await document.action((capture) => request('POST', 'program/assemble', capture))
}
export async function discardProgram(programId: string): Promise<void> {
  await request('POST', 'program/discard', { program_id: programId })
  documents.delete(programId)
  changed()
}
export function startDocuments(): void {
  let instance: string | null = null
  useCore.subscribe((state) => {
    if (!state.live.state) return
    const changedInstance = instance !== null && instance !== state.live.instance
    instance = state.live.instance
    if (changedInstance) {
      const current = new Map(
        state.live.state.programs.map((program) => [program.program_id, program]),
      )
      for (const [id, document] of documents) {
        const program = current.get(id)
        if (program) document.resynchronize(program)
        else if (document.snapshot().program.is_open) document.markMissing()
      }
    }
    for (const program of state.live.state.programs) {
      if (program.is_open || documents.has(program.program_id)) acceptProgram(program)
      else prepareExample(program)
    }
  })
  onBeforeClose(
    async () => {
      await Promise.all(
        [...documents.values()]
          .filter((document) => document.snapshot().program.is_open)
          .map((document) => document.freezeAndReceive()),
      )
    },
    () => documents.forEach((document) => document.unfreeze()),
  )
}
