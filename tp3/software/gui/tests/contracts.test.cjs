const { test } = require('node:test')
const assert = require('node:assert/strict')
const { randomUUID } = require('node:crypto')
const { validateConnection, validateEnvelope } = require('../.test-build/shared/contracts')
const { applyEvent, emptyState } = require('../.test-build/renderer/live-state')

const instance = '1f341c09-06c5-4f62-806a-1b8f9506820c'
const discovery = {
  base_url: 'http://127.0.0.1:49152',
  instance_id: instance,
  api_version: 1,
  access_token: 'a'.repeat(43),
}
const state = {
  board: {
    connection_status: 'closed',
    port: null,
    controller: null,
    preparation_required: true,
    recovery_pending: false,
  },
  works: [],
  programs: [],
  assemblies: [],
  loaded_image: { status: 'unknown', program_id: null, source_version: null, byte_count: null },
  sessions: [],
  preferences: {
    schema_version: 1,
    default_author: null,
    record_by_default: true,
    last_serial_port: null,
    ui_zoom: 1,
    language: 'es',
  },
  limitations: [],
}
const initial = { instance_id: instance, type: 'state', state_revision: 12, data: state }

test('TEST-PC-015: discovery rejects remote, redirected and malformed destinations', () => {
  assert.deepEqual(validateConnection(discovery), discovery)
  for (const url of [
    'http://example.com:80',
    'https://127.0.0.1:49152',
    'http://localhost:49152',
    'http://127.0.0.1:49152/',
    'http://127.0.0.1:49152?x=1',
    'http://user@127.0.0.1:49152',
    'http://127.0.0.1:0',
    'http://127.0.0.1:65536',
  ])
    assert.throws(() => validateConnection({ ...discovery, base_url: url }))
  assert.throws(() => validateConnection({ ...discovery, api_version: 2 }), /CORE_INCOMPATIBLE/)
})
test('TEST-PC-008: complete initial state then consecutive block replacement', () => {
  const a = applyEvent(emptyState, initial, instance)
  const works = [
    {
      work_id: randomUUID(),
      client_type: 'cli',
      owns_board: false,
      pending_commands: [],
      session_id: null,
      debug_open: false,
    },
  ]
  const b = applyEvent(
    a,
    { instance_id: instance, type: 'update', state_revision: 13, data: { works } },
    instance,
  )
  assert.equal(b.revision, 13)
  assert.deepEqual(b.state.works, works)
  assert.deepEqual(b.state.board, state.board)
  assert.deepEqual(a.state.works, [])
})
test('TEST-PC-008: old updates cannot roll back the view', () => {
  const a = applyEvent(emptyState, initial, instance)
  assert.equal(applyEvent(a, { ...initial, state_revision: 10 }, instance), a)
  for (const revision of [10, 11, 12])
    assert.equal(
      applyEvent(
        a,
        { ...initial, type: 'update', state_revision: revision, data: { works: [] } },
        instance,
      ),
      a,
    )
})
test('TEST-PC-008: gap, wrong instance and missing initial state require resynchronization', () => {
  const a = applyEvent(emptyState, initial, instance)
  assert.throws(() => applyEvent(a, { ...initial, type: 'update', state_revision: 14 }, instance))
  assert.throws(() => applyEvent(a, { ...initial, instance_id: randomUUID() }, instance))
  assert.throws(() => applyEvent(emptyState, { ...initial, type: 'update' }, instance))
  assert.throws(() => applyEvent(emptyState, { ...initial, data: { works: [] } }, instance))
})
test('TEST-PC-008: new full state restores synchronization without FPGA activity', () => {
  const a = applyEvent(emptyState, initial, instance)
  const b = applyEvent(a, { ...initial, state_revision: 25 }, instance)
  assert.equal(b.revision, 25)
  const next = randomUUID()
  assert.equal(
    applyEvent(b, { ...initial, instance_id: next, state_revision: 0 }, next).instance,
    next,
  )
})
test('TEST-PC-013: response envelopes preserve result/error exclusivity', () => {
  assert.deepEqual(validateEnvelope({ result: state.board, error: null }).result, state.board)
  assert.throws(() =>
    validateEnvelope({ result: state.board, error: { code: 'X', message: 'Error' } }),
  )
  assert.throws(() => validateEnvelope({ result: null, error: null }))
})

test('TEST-PC-008: malformed blocks cannot replace live state', () => {
  const a = applyEvent(emptyState, initial, instance)
  for (const data of [
    { works: 'invalid' },
    { board: {} },
    { preferences: null },
    { programs: null },
    { not_a_block: [] },
  ])
    assert.throws(() =>
      applyEvent(a, { ...initial, type: 'update', state_revision: 13, data }, instance),
    )
})
