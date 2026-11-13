const { test } = require('node:test')
const assert = require('node:assert/strict')
const { randomUUID } = require('node:crypto')
const { DocumentSync } = require('../.test-build/renderer/document-sync')
const program = () => ({
  program_id: randomUUID(),
  source_version: randomUUID(),
  source_text: '',
  source_path: null,
  example_id: null,
  is_open: true,
  edit_protected: false,
  saved_version: null,
  recovery_version: null,
})
const tick = () => new Promise((resolve) => setImmediate(resolve))
function controlled() {
  const calls = []
  const doc = new DocumentSync(
    program(),
    (capture) =>
      new Promise((resolve, reject) =>
        calls.push({
          capture,
          resolve: () => resolve({ ...doc.snapshot().program, ...capture }),
          reject,
        }),
      ),
  )
  return { doc, calls }
}
test('TEST-PC-017: one update in flight and newest pending text retained', async () => {
  const { doc, calls } = controlled()
  doc.edit('B')
  doc.edit('C')
  doc.edit('D')
  assert.equal(calls.length, 1)
  calls[0].resolve()
  await tick()
  assert.equal(calls.length, 2)
  assert.equal(calls[1].capture.source_text, 'D')
  assert.equal(doc.snapshot().capture.source_text, 'D')
  calls[1].resolve()
  await tick()
})
test('TEST-PC-017: an action keeps its chosen revision while later edits are coalesced', async () => {
  const { doc, calls } = controlled()
  doc.edit('B')
  doc.edit('C')
  const actions = []
  const result = doc.action(async (capture) => {
    actions.push(capture)
    return capture.source_text
  })
  doc.edit('D')
  doc.edit('E')
  assert.equal(actions.length, 0)
  calls[0].resolve()
  await tick()
  assert.equal(calls[1].capture.source_text, 'C')
  calls[1].resolve()
  await tick()
  assert.equal(await result, 'C')
  assert.equal(doc.snapshot().capture.source_text, 'E')
  assert.equal(calls[2].capture.source_text, 'E')
  calls[2].resolve()
  await tick()
})
test('TEST-PC-017: a failed receipt prevents the dependent operation', async () => {
  const { doc, calls } = controlled()
  doc.edit('B')
  let executed = false
  const result = doc.action(async () => {
    executed = true
  })
  const rejected = assert.rejects(result, /failed/)
  calls[0].reject(new Error('failed'))
  await rejected
  assert.equal(executed, false)
  assert.equal(doc.snapshot().capture.source_text, 'B')
  const retry = doc.retry()
  await tick()
  calls.at(-1).resolve()
  await retry
})
test('TEST-PC-026: close freezes the final revision and leaves no updates behind', async () => {
  const { doc, calls } = controlled()
  doc.edit('B')
  doc.edit('C')
  let final
  const close = doc.close(async (capture) => {
    final = capture
  })
  doc.edit('D')
  calls[0].resolve()
  await tick()
  calls[1].resolve()
  await close
  await tick()
  assert.equal(final.source_text, 'C')
  assert.equal(doc.snapshot().capture.source_text, 'C')
  assert.equal(calls.length, 2)
})
test('TEST-PC-017: an old SSE echo cannot replace the current model', async () => {
  const { doc, calls } = controlled()
  doc.edit('B')
  const b = calls[0].capture
  doc.edit('C')
  doc.apply({ ...doc.snapshot().program, ...b, recovery_version: b.source_version })
  assert.equal(doc.snapshot().capture.source_text, 'C')
  calls[0].resolve()
  await tick()
  calls[1].resolve()
  await tick()
  doc.apply({ ...doc.snapshot().program, ...b })
  assert.equal(doc.snapshot().capture.source_text, 'C')
})
test('TEST-PC-010: new core instance requires a fresh receipt for local edits', async () => {
  const { doc, calls } = controlled()
  const restored = { ...doc.snapshot().program }
  doc.edit('B')
  calls[0].resolve()
  await tick()
  doc.resynchronize(restored)
  await tick()
  assert.equal(calls.length, 2)
  assert.equal(calls[1].capture.source_text, 'B')
  calls[1].resolve()
  await tick()
  assert.equal(doc.snapshot().capture.source_text, 'B')
})
test('TEST-PC-010: old instance cannot acknowledge or repeat a pending action', async () => {
  const { doc, calls } = controlled()
  const restored = { ...doc.snapshot().program }
  doc.edit('B')
  let executed = false
  const action = doc.action(async () => {
    executed = true
  })
  const rejected = assert.rejects(action, /instancia/)
  doc.resynchronize(restored)
  calls[0].resolve()
  await rejected
  await tick()
  assert.equal(executed, false)
  assert.equal(calls.length, 2)
  calls[1].resolve()
  await tick()
})
test('TEST-PC-010: a missing unconfirmed draft keeps its local text', async () => {
  const { doc, calls } = controlled()
  doc.markMissing()
  doc.edit('kept locally')
  assert.equal(doc.snapshot().capture.source_text, 'kept locally')
  assert.equal(doc.snapshot().missing, true)
  assert.equal(calls.length, 0)
  await assert.rejects(
    doc.action(async () => {}),
    /borrador/,
  )
})
