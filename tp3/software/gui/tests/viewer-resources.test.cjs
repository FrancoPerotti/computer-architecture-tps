const { test } = require('node:test')
const assert = require('node:assert/strict')
const {
  readFileSync,
  mkdtempSync,
  mkdirSync,
  copyFileSync,
  writeFileSync,
  rmSync,
} = require('node:fs')
const { resolve } = require('node:path')
const { tmpdir } = require('node:os')
const { execFileSync } = require('node:child_process')
const { createHash } = require('node:crypto')
const { inflateRawSync } = require('node:zlib')
const content = resolve(__dirname, '../../resources/content')
const read = (name) => readFileSync(resolve(content, name), 'utf8')
const hash = (value) => createHash('sha256').update(value).digest('hex')
const unpack = (value) =>
  decodeURIComponent(inflateRawSync(Buffer.from(value, 'base64')).toString())
test('PC-I07 prepared views preserve the pinned runtime and use the canonical complete XML', () => {
  const source = read('viewer/index.html'),
    runtime = source.match(/<script id="drawio-runtime">([\s\S]*?)<\/script>/)[1]
  const manifest = JSON.parse(read('viewer/generated.json'))
  assert.equal(
    manifest.generator_sha256,
    hash(readFileSync(resolve(__dirname, '../../packaging/build_viewer.cjs'))),
  )
  assert.equal(
    manifest.tools['viewer_resources.cjs'],
    hash(readFileSync(resolve(__dirname, '../../packaging/viewer_resources.cjs'))),
  )
  for (const [name, sha] of Object.entries(manifest.inputs))
    assert.equal(hash(read(name)), sha, name)
  for (const [name, sha] of Object.entries(manifest.outputs)) {
    const html = read(name)
    assert.equal(hash(html), sha, name)
    assert.equal(
      hash(html.match(/<script id="drawio-runtime">([\s\S]*?)<\/script>/)[1]),
      hash(runtime),
      'The approved SDK was altered',
    )
    const packed = JSON.parse(html.match(/<script id="diagram-data"[^>]*>([\s\S]*?)<\/script>/)[1])
    const data = JSON.parse(unpack(packed.compressed))
    assert.equal(unpack(data.xml), read('diagram.drawio.xml'))
    assert.equal(Object.keys(data.instructions).length, 33)
    assert.equal(data.pages.length, 166)
    const originalData = JSON.parse(
      unpack(
        JSON.parse(source.match(/<script id="diagram-data"[^>]*>([\s\S]*?)<\/script>/)[1])
          .compressed,
      ),
    )
    assert.deepEqual(data.signals, originalData.signals)
    for (const page of data.pages) {
      const original = originalData.pages.find((row) => row.id === page.id)
      assert.deepEqual(page.module_explanations, original.module_explanations)
      for (const [id, detail] of Object.entries(page.connections)) {
        assert.equal(detail.description, original.connections[id].description)
        assert.deepEqual(detail.paragraphs, original.connections[id].paragraphs)
      }
    }
  }
  const session = read('viewer/session.html')
  const sdkEnd = session.indexOf('</script>', session.indexOf('<script id="drawio-runtime">'))
  assert.ok(
    session.indexOf('/* The session keeps the complete approved graph', sdkEnd) > sdkEnd,
    'Session CSS was injected into the runtime',
  )
})
test('PC-I07 editorial changes reach the prepared selector, assumptions, stage and module without changing the runtime', () => {
  const temporary = mkdtempSync(resolve(tmpdir(), 'viewrv-education-'))
  try {
    const manifest = JSON.parse(read('viewer/generated.json'))
    for (const name of [...Object.keys(manifest.inputs), 'viewer/provenance.json']) {
      const destination = resolve(temporary, name)
      mkdirSync(resolve(destination, '..'), { recursive: true })
      copyFileSync(resolve(content, name), destination)
    }
    const education = JSON.parse(read('es/education.json'))
    education.assumptions = ['Supuesto editorial de prueba.']
    education.instructions.addi.example = 'ADDI <ejemplo> & revisión'
    education.instructions.addi.stages[2].description = 'Explicación EX corregida.'
    education.modules['ex.alu'].description = 'Función editorial corregida.'
    education.modules['if.pc'].presentation.description = 'Tooltip general corregido.'
    education.instructions.addi.module_explanations['ex.alu'] =
      'Explicación por instrucción corregida.'
    education.instructions.addi.stages[2].module_explanations['ex.alu'] =
      'Explicación contextual de EX corregida.'
    const connectionId = Object.keys(
      education.instructions.addi.stages[2].connection_explanations,
    )[0]
    education.instructions.addi.stages[2].connection_explanations[connectionId] = {
      description: 'Conexión contextual corregida.',
      paragraphs: ['Párrafo contextual corregido.'],
    }
    writeFileSync(resolve(temporary, 'es/education.json'), JSON.stringify(education))
    execFileSync(
      process.execPath,
      [resolve(__dirname, '../../packaging/build_viewer.cjs'), temporary],
      { stdio: 'pipe' },
    )
    const html = readFileSync(resolve(temporary, 'viewer/explore.html'), 'utf8')
    const packed = JSON.parse(html.match(/<script id="diagram-data"[^>]*>([\s\S]*?)<\/script>/)[1])
    const data = JSON.parse(unpack(packed.compressed)),
      pages = new Map(data.pages.map((page) => [page.id, page]))
    assert.ok(html.includes('ADDI &lt;ejemplo&gt; &amp; revisión</option>'))
    assert.deepEqual(pages.get(data.presentation.overview.id).paragraphs, education.assumptions)
    assert.equal(
      pages.get(data.instructions.addi.stages[2].id).description,
      'Explicación EX corregida.',
    )
    const bindings = JSON.parse(read('diagram_bindings.json'))
    assert.equal(data.blocks[bindings.blocks['ex.alu']].function, 'Función editorial corregida.')
    assert.equal(
      data.module_presentation[bindings.blocks['if.pc']].description,
      'Tooltip general corregido.',
    )
    assert.equal(
      data.instructions.addi.module_explanations[bindings.blocks['ex.alu']],
      'Explicación por instrucción corregida.',
    )
    const stage = pages.get(data.instructions.addi.stages[2].id)
    assert.equal(
      stage.module_explanations[bindings.blocks['ex.alu']],
      'Explicación contextual de EX corregida.',
    )
    assert.deepEqual(stage.connections[connectionId].paragraphs, ['Párrafo contextual corregido.'])
    assert.equal(
      hash(html.match(/<script id="drawio-runtime">([\s\S]*?)<\/script>/)[1]),
      hash(read('viewer/index.html').match(/<script id="drawio-runtime">([\s\S]*?)<\/script>/)[1]),
    )
  } finally {
    rmSync(temporary, { recursive: true, force: true })
  }
})
