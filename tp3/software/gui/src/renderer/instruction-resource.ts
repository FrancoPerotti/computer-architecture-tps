import type { Instruction } from './instructions'

type FetchResource = (url: string) => Promise<Pick<Response, 'ok' | 'json'>>
const message = 'No se pudo cargar el catálogo de instrucciones. Reintentá la carga.'
const record = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value)

/** Validate the same local contract for the language service and the catalog. */
export async function readInstructions(
  fetchResource: FetchResource = fetch,
): Promise<Instruction[]> {
  try {
    const response = await fetchResource('viewrv://app/content/instructions.json')
    if (!response.ok) throw new Error('Instruction resource HTTP failure')
    const value: unknown = await response.json()
    if (
      !Array.isArray(value) ||
      !value.length ||
      value.some(
        (item) =>
          !record(item) ||
          !['mnemonic', 'description', 'syntax', 'example'].every(
            (key) => typeof item[key] === 'string' && item[key].length > 0,
          ) ||
          !Array.isArray(item.operands) ||
          item.operands.some(
            (operand) =>
              !record(operand) ||
              typeof operand.name !== 'string' ||
              typeof operand.description !== 'string',
          ) ||
          !Array.isArray(item.notes) ||
          item.notes.some((note) => typeof note !== 'string'),
      )
    )
      throw new Error('Invalid instruction resource contract')
    const instructions = value as Instruction[]
    if (new Set(instructions.map((item) => item.mnemonic)).size !== instructions.length)
      throw new Error('Duplicate instruction')
    return instructions
  } catch (cause) {
    throw new Error(message, { cause })
  }
}
