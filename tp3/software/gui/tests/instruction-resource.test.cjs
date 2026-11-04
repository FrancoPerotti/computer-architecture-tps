const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readInstructions } = require('../.test-build/renderer/instruction-resource')
const instruction = {
  mnemonic: 'add',
  description: 'Suma.',
  syntax: 'add rd, rs1, rs2',
  operands: [{ name: 'rd', description: 'Destino.' }],
  example: 'add x1, x2, x3',
  notes: [],
}

test('instruction resources reject HTTP failures before attempting JSON parsing', async () => {
  let parsed = false
  await assert.rejects(
    readInstructions(async () => ({
      ok: false,
      json: async () => {
        parsed = true
        return []
      },
    })),
    /No se pudo cargar el catálogo/,
  )
  assert.equal(parsed, false)
})
test('instruction resources validate JSON, entries and unique mnemonics', async () => {
  for (const value of [
    null,
    [],
    [instruction, instruction],
    [{ ...instruction, notes: null }],
    [{ ...instruction, operands: [{ name: 'rd' }] }],
  ]) {
    await assert.rejects(
      readInstructions(async () => ({ ok: true, json: async () => value })),
      /No se pudo cargar el catálogo/,
    )
  }
  await assert.rejects(
    readInstructions(async () => ({
      ok: true,
      json: async () => {
        throw new SyntaxError('bad JSON')
      },
    })),
    /No se pudo cargar el catálogo/,
  )
})
test('a failed instruction request does not poison a later retry', async () => {
  let count = 0
  const resource = async () => {
    if (++count === 1) throw Error('offline')
    return { ok: true, json: async () => [instruction] }
  }
  await assert.rejects(readInstructions(resource), /Reintentá la carga/)
  assert.deepEqual(await readInstructions(resource), [instruction])
})
