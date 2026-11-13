const test = require('node:test')
const assert = require('node:assert/strict')
const { DocumentSync } = require('../.test-build/renderer/document-sync.js')
const {
  programWorkflow,
  formatValue,
  actionReason,
} = require('../.test-build/renderer/ide-workflow.js')
function fixture() {
  const program = {
    program_id: crypto.randomUUID(),
    source_version: crypto.randomUUID(),
    source_text: 'addi x1,x0,5\nhalt\n',
    source_path: null,
    example_id: null,
    is_open: true,
    edit_protected: false,
    saved_version: null,
    recovery_version: null,
  }
  const document = new DocumentSync(program, async (capture) => ({ ...program, ...capture }))
  return { program, document, events: { progress() {}, assembled() {}, loaded() {} } }
}
test('TEST-PC-017: combined action stops when editing precedes LOAD admission', async () => {
  const { document, events } = fixture()
  const calls = []
  const call = async (path, body) => {
    calls.push(path)
    if (path === 'program/assemble') {
      document.edit('# changed before LOAD\nhalt\n')
      return { image: [11, 0, 0, 0], pc_to_line: [] }
    }
    throw Error('Unexpected later request')
  }
  await assert.rejects(programWorkflow(document, 'combined', call, events), /cambió antes de LOAD/)
  assert.deepEqual(calls, ['program/assemble'])
})
test('TEST-PC-017: edits after LOAD begins preserve the confirmed reference for RUN', async () => {
  const { program, document, events } = fixture()
  const calls = []
  const call = async (path, body) => {
    calls.push([path, { ...body }])
    if (path === 'program/load') {
      document.edit('# edited while LOAD pending\nhalt\n')
      return {
        program_id: program.program_id,
        source_version: program.source_version,
        byte_count: 8,
      }
    }
    return {
      image: [147, 0, 80, 0, 11, 0, 0, 0],
      pc_to_line: [
        { pc: 0, line: 1 },
        { pc: 4, line: 2 },
      ],
    }
  }
  await programWorkflow(document, 'combined', call, events)
  assert.deepEqual(
    calls.map((item) => item[0]),
    ['program/assemble', 'program/load', 'run/start'],
  )
  assert.deepEqual(calls[2][1], {
    program_id: program.program_id,
    source_version: program.source_version,
  })
  assert.notEqual(document.snapshot().capture.source_version, program.source_version)
})
test('TEST-PC-015: an unconfirmed load never launches RUN or retries LOAD', async () => {
  const { document, events } = fixture()
  const calls = []
  const call = async (path) => {
    calls.push(path)
    if (path === 'program/load') throw Error('LOAD_RESULT_UNCONFIRMED')
    return {}
  }
  await assert.rejects(
    programWorkflow(document, 'combined', call, events),
    /LOAD_RESULT_UNCONFIRMED/,
  )
  assert.deepEqual(calls, ['program/assemble', 'program/load'])
})
test('TEST-PC-004 / TEST-PC-012: per-value formats preserve unsigned 32-bit and full 64-bit counts', () => {
  assert.equal(formatValue(4294967295, 32, 'hex'), '0xffffffff')
  assert.equal(formatValue(4294967295, 32, 'signed'), '-1')
  assert.equal(formatValue('18446744073709551615', 64, 'unsigned'), '18446744073709551615')
  assert.equal(formatValue(128, 8, 'binary'), '0b10000000')
})
