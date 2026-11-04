const { test } = require('node:test')
const assert = require('node:assert/strict')
const { readdirSync, readFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { spawnSync } = require('node:child_process')
const { createAssemblyLineFormatter } = require('../.test-build/renderer/assembly-format')
const instructions = require('../../resources/content/instructions.json')
const formatLine = createAssemblyLineFormatter(instructions)
const options = { insertSpaces: true, tabSize: 4 }
const format = (text, settings = options) =>
  text
    .split(/(\r\n|\n)/)
    .map((part, i) => (i % 2 ? part : formatLine(part, settings)))
    .join('')

test('Assembly formatter preserves labels, comment contents, line numbers, BOM and endings', () => {
  const original =
    '\uFEFF  Start \t:  addi\tx1 ,x0, -0X08 \t# aquí, (x1):  # texto  \r\n\t# comentario alineado\r\n \t\r\n Fin :\thalt'
  const expected =
    '\uFEFFStart: addi x1, x0, -0X08  # aquí, (x1):  # texto  \r\n\t# comentario alineado\r\n\r\nFin: halt'
  assert.equal(format(original), expected)
  assert.equal(format(expected), expected)
  assert.equal(
    format('Loop :\n\tlw\tx3 , -4 ( sp )\n halt\n\n'),
    'Loop:\n    lw x3, -4(sp)\n    halt\n\n',
  )
  assert.equal(format('  add x1,x2,x3', { insertSpaces: false, tabSize: 8 }), '\tadd x1, x2, x3')
  assert.equal(format('halt', { insertSpaces: true, tabSize: 2 }), '  halt')
})

test('Assembly formatter leaves unsupported syntax untouched and never repairs split tokens', () => {
  for (const text of [
    '  .string "a , b # c"',
    ' ADD x1 , x2,x3 ',
    ' weird x1,x2 ',
    'addi x1, x0,\u00a01',
    'lw x1, 0\r(x2)',
    'add x1,x2,x3; halt',
  ])
    assert.equal(format(text), text)
  for (const text of [
    'addi x 1,x0,1',
    'lw x1,- 4 ( x2 )',
    'addi x1,x0,- 1',
    'addi x1 x0 1',
    'addi x1,',
    'halt ,',
  ]) {
    const formatted = format(text)
    assert.equal(format(formatted), formatted)
  }
  assert.equal(format('lw x1,- 4 ( x2 )'), '    lw x1, - 4 ( x2 )')
})

test('Bundled examples use editor formatting and retain assembler bytes and PC–line maps', () => {
  const directory = resolve(__dirname, '../../resources/content/examples')
  const cases = readdirSync(directory)
    .filter((name) => name.endsWith('.s'))
    .map((name) => {
      const text = readFileSync(resolve(directory, name), 'utf8')
      assert.equal(format(text), text, `${name}: el ejemplo debe usar el formato del editor`)
      return { name, text }
    })
  // Exercise allowed whitespace beyond the already tidy bundled examples.
  cases.push({
    name: 'labels-memory-bom-crlf',
    text: '\uFEFF  Start :  addi\tx1 ,x0, +012 # unicode á\r\n Loop:\r\n sw x1 , -4 ( sp )\r\n lw x3,0 (x2)\r\n bne x1 , x0 , Loop\r\n jal x0,End\r\n End : halt',
  })
  const invalid = [
    'addi x 1,x0,1',
    'lw x1,- 4 ( x2 )',
    'addi x1,x0,- 1',
    'addi x1 x0 1',
    'addi x1,',
    'halt ,',
    'add x1,x2,x3; halt',
    'lw x1, (x2)',
    'bad: bad2: halt',
    'addi x1,x0,\u00a01',
  ]
  cases.push(...invalid.map((text) => ({ name: text, text })))
  const pairs = cases.map(({ name, text }) => ({ name, original: text, formatted: format(text) }))
  for (const { formatted } of pairs) assert.equal(format(formatted), formatted)
  const result = spawnSync(
    resolve(__dirname, '../../.venv/bin/python'),
    [
      '-c',
      `
import json, sys
from software.assembler import assemble
for case in json.load(sys.stdin):
    before, after = assemble(case['original']), assemble(case['formatted'])
    assert (before.image, before.pc_to_line) == (after.image, after.pc_to_line), case['name']
    assert (before.error is None) == (after.error is None), case['name']
    if before.error:
        assert before.error.line == after.error.line, case['name']
`,
    ],
    { cwd: resolve(__dirname, '../../..'), input: JSON.stringify(pairs), encoding: 'utf8' },
  )
  assert.equal(result.status, 0, result.stderr || String(result.error))
  assert.ok(cases.length >= 59)
})
