const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { guideAt } = require('../.test-build/renderer/examples.js')
const content = resolve(__dirname, '../../resources/content')
const catalog = JSON.parse(readFileSync(resolve(content, 'examples/catalog.json'), 'utf8'))
const entry = catalog.find((entry) => entry.example_id === 'load-use')
const original = readFileSync(resolve(content, entry.source_path), 'utf8')
const guide = JSON.parse(readFileSync(resolve(content, entry.guide_path), 'utf8'))
const reference = { ...entry, original, guide, memoryProfile: 'REFERENCE' }
test('PC-I07 guide uses the received cycle and exact original source without predicting edited variants', () => {
  assert.equal(guideAt(reference, original, 5).cycle, 5)
  assert.equal(guideAt(reference, original, '5').cycle, 5)
  assert.equal(guideAt(reference, original, undefined), null)
  assert.equal(guideAt(reference, original, 0), null)
  assert.equal(guideAt(reference, original, 10), null)
  assert.equal(guideAt(reference, original + '# variante\n', 5), null)
  assert.equal(guideAt({ ...reference, memoryProfile: 'other' }, original, 5), null)
  // The guide does not manufacture rows for counters outside its authored range.
  assert.equal(guideAt(reference, original, '18446744073709551615'), null)
})
test('PC-I07 load-use reference retains the same occurrence and inserts one bubble', () => {
  const before = guide.cycles[3].positions,
    stalled = guide.cycles[4].positions,
    after = guide.cycles[5].positions
  const consumer = before.find((position) => position.latch === 'IF/ID')
  assert.equal(consumer.pc, 12)
  assert.deepEqual(
    stalled.find((position) => position.latch === 'IF/ID'),
    consumer,
  )
  assert.equal(
    stalled.some((position) => position.latch === 'ID/EX'),
    false,
  )
  assert.deepEqual(
    after.find((position) => position.latch === 'ID/EX'),
    { ...consumer, latch: 'ID/EX' },
  )
})

test('PC-I07 guide does not rebind a loop prefix after a counter gap or wrap', () => {
  const entry = catalog.find((entry) => entry.example_id === 'loop-self')
  const original = readFileSync(resolve(content, entry.source_path), 'utf8')
  const guide = JSON.parse(readFileSync(resolve(content, entry.guide_path), 'utf8'))
  const reference = { ...entry, original, guide, memoryProfile: 'REFERENCE' }
  assert.equal(guideAt(reference, original, '1', 1).cycle, 1)
  assert.equal(guideAt(reference, original, '1', 10), null)
  assert.equal(guideAt(reference, original, '6', 5), null)
  assert.equal(guideAt(reference, original, '1'), null)
})
