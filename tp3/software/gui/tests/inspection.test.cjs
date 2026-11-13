const { test } = require('node:test')
const assert = require('node:assert/strict')
const core = require('../.test-build/renderer/core-client.js')
const selection = require('../.test-build/renderer/inspection.js')
const tick = () => new Promise((resolve) => setImmediate(resolve))
function fixture() {
  selection.useInspection.setState({ items: {} })
  const session = {
    session_id: crypto.randomUUID(),
    program_id: crypto.randomUUID(),
    source_version: crypto.randomUUID(),
    debug_open: true,
    last_observation: { step_index: 1 },
    outcome: null,
  }
  const state = { sessions: [session] }
  core.useCore.setState({
    live: { instance: crypto.randomUUID(), revision: 1, state },
    synchronized: true,
  })
  const follow = {
    session_id: session.session_id,
    program_id: session.program_id,
    source_version: session.source_version,
    origin_step_index: 1,
    origin_latch: 'IF/ID',
    step_index: 1,
    last_latch: 'IF/ID',
    pc: 0,
    instruction: 0x00500093,
    status: 'following',
    reason: null,
  }
  return {
    session,
    state,
    follow,
    selected: () => selection.useInspection.getState().items[session.session_id],
    step(index) {
      session.last_observation = { step_index: index }
      core.useCore.setState({ live: { ...core.useCore.getState().live, state: { ...state } } })
    },
  }
}
test('PC-I07 selection ignores a late start response after an explicit different component choice', async () => {
  const f = fixture()
  let finish
  core.request = async (method, path) => {
    assert.equal(path, 'interpretation/follow')
    return new Promise((resolve) => (finish = resolve))
  }
  const pending = selection.followOccurrence(f.session, 'IF/ID')
  selection.pickComponent(f.session.session_id, 'ex.alu')
  finish(f.follow)
  await pending
  assert.equal(f.selected().component, 'ex.alu')
  assert.equal(f.selected().follow, null)
  assert.equal(f.selected().starting, false)
})
test('PC-I07 inspecting a connection cancels pending occurrence selection and rejects its late reply', async () => {
  const f = fixture()
  let finish
  core.request = async () => new Promise((resolve) => (finish = resolve))
  const pending = selection.followOccurrence(f.session, 'IF/ID')
  const connection = {
    id: 'connection-128',
    name: 'read_data1',
    route: 'Registers → RS1 Bypass MUX',
    description: 'Explicación conceptual.',
  }
  selection.pickConnection(f.session.session_id, connection)
  finish(f.follow)
  await pending
  assert.deepEqual(f.selected().connection, connection)
  assert.equal(f.selected().component, null)
  assert.equal(f.selected().latch, null)
  assert.equal(f.selected().follow, null)
  assert.equal(f.selected().starting, false)
})
test('PC-I07 communication loss ends an initial follow and cannot be undone by its late response', async () => {
  const f = fixture()
  let finish
  core.request = async () => new Promise((resolve) => (finish = resolve))
  const pending = selection.followOccurrence(f.session, 'IF/ID')
  core.useCore.setState({ synchronized: false })
  finish(f.follow)
  await pending
  assert.equal(f.selected().follow, null)
  assert.equal(f.selected().starting, false)
  assert.match(f.selected().notice, /continuidad/)
})
test('PC-I07 communication loss ends pending continuity without allowing a late response to resume it', async () => {
  const f = fixture()
  let finish
  core.request = async (_method, path, body) => {
    assert.equal(path, 'interpretation/follow')
    return body.selection ? f.follow : new Promise((resolve) => (finish = resolve))
  }
  await selection.followOccurrence(f.session, 'IF/ID')
  f.step(2)
  core.useCore.setState({ synchronized: false })
  finish({ ...f.follow, step_index: 2, last_latch: 'ID/EX' })
  await tick()
  assert.equal(f.selected().follow.status, 'unavailable')
  assert.equal(f.selected().follow.reason, 'gap')
  assert.equal(f.selected().component, 'latch.if_id')
})
test('PC-I07 a newer observation received during the calculation is checked afterward through the same pure endpoint', async () => {
  const f = fixture(),
    calls = []
  let finish
  core.request = async (_method, path, body) => {
    assert.equal(path, 'interpretation/follow')
    calls.push(body)
    if (body.selection) return f.follow
    if (body.follow.step_index === 1) return new Promise((resolve) => (finish = resolve))
    return { ...f.follow, step_index: 3, last_latch: 'EX/MEM' }
  }
  await selection.followOccurrence(f.session, 'IF/ID')
  f.step(2)
  f.step(3)
  finish({ ...f.follow, step_index: 2, last_latch: 'ID/EX' })
  await tick()
  await tick()
  assert.deepEqual(
    calls.filter((body) => body.follow).map((body) => body.follow.step_index),
    [1, 2],
  )
  assert.equal(f.selected().follow.step_index, 3)
  assert.equal(f.selected().component, 'latch.ex_mem')
})
