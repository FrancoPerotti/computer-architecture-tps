import type { LatchName } from '../shared/contracts'
export interface ExampleEntry {
  example_id: string
  title: string
  objective: string
  source_path: string
  guide_path: string
  expected_observations: string[]
  related_instruction_ids: string[]
  category: string
  source_sha256: string
  memory_profiles: string[]
  focus_instruction_id: string | null
  expected_state: {
    registers?: Record<string, number>
    memory?: Record<string, number>
    used_count?: number
  }
}
export interface GuideCycle {
  cycle: number
  positions: { latch: LatchName; pc: number; occurrence: string }[]
  explanation: string
}
export interface ExampleGuide {
  schema_version: number
  example_id: string
  source_sha256: string
  memory_profiles: string[]
  assumptions: string[]
  cycles: GuideCycle[]
  prefix_only: boolean
  terminal: {
    cycle: number
    execution_status: 'finished' | 'fault'
    fault_cause?: number
    fault_pc?: number
  } | null
}
export interface ExampleReference extends ExampleEntry {
  original: string
  guide: ExampleGuide
  memoryProfile: string
}
const references = new Map<string, Promise<ExampleReference>>()
let bank: Promise<{ catalog: ExampleEntry[]; memoryProfile: string }> | null = null
async function read(path: string): Promise<string> {
  const response = await fetch(`viewrv://app/content/${path}`)
  if (!response.ok) throw Error('No se pudo abrir el recurso educativo local: ' + path)
  return response.text()
}
export async function sourceDigest(text: string): Promise<string> {
  return Array.from(
    new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))),
  )
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}
export function exampleBank(): Promise<{ catalog: ExampleEntry[]; memoryProfile: string }> {
  return (bank ??= Promise.all([read('examples/catalog.json'), read('processor_profile.json')])
    .then(([catalog, profile]) => ({
      catalog: JSON.parse(catalog),
      memoryProfile: JSON.parse(profile).memory_profile,
    }))
    .catch((error) => {
      bank = null
      throw error
    }))
}
export async function exampleReference(id: string): Promise<ExampleReference> {
  const saved = references.get(id)
  if (saved) return saved
  const pending = (async () => {
    const { catalog, memoryProfile } = await exampleBank(),
      entry = catalog.find((entry) => entry.example_id === id)
    if (
      !entry ||
      entry.source_path !== `examples/${id}.s` ||
      entry.guide_path !== `examples/guides/${id}.json` ||
      !/^[a-z0-9-]+$/.test(id)
    )
      throw Error('Referencia de ejemplo inválida.')
    const [original, guideText] = await Promise.all([
        read(entry.source_path),
        read(entry.guide_path),
      ]),
      guide = JSON.parse(guideText) as ExampleGuide
    if (
      (await sourceDigest(original)) !== entry.source_sha256 ||
      guide.schema_version !== 1 ||
      guide.source_sha256 !== entry.source_sha256 ||
      guide.example_id !== id
    )
      throw Error('La guía no coincide con el programa original.')
    return { ...entry, original, guide, memoryProfile }
  })().catch((error) => {
    references.delete(id)
    throw error
  })
  references.set(id, pending)
  return pending
}
export async function originalExample(source: string): Promise<ExampleReference | null> {
  const { catalog } = await exampleBank(),
    sha = await sourceDigest(source),
    entry = catalog.find((entry) => entry.source_sha256 === sha)
  return entry ? exampleReference(entry.example_id) : null
}
export function guideAt(
  reference: ExampleReference,
  source: string,
  cycle: number | string | undefined,
  stepIndex?: number,
): GuideCycle | null {
  if (source !== reference.original || !reference.memory_profiles.includes(reference.memoryProfile))
    return null
  if (
    (stepIndex !== undefined && String(stepIndex) !== String(cycle)) ||
    (reference.guide.prefix_only && stepIndex === undefined)
  )
    return null
  return reference.guide.cycles.find((row) => String(row.cycle) === String(cycle)) ?? null
}
