const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const os = require('node:os')
const { execFileSync } = require('node:child_process')
const { createHash } = require('node:crypto')
const { graphCells } = require('../../packaging/viewer_resources.cjs')
const { copyContent, editDrawing, unpack } = require('./drawing-fixture.cjs')
const content = path.resolve(__dirname, '../../resources/content'),
  builder = path.resolve(__dirname, '../../packaging/build_viewer.cjs')
const hash = (value) => createHash('sha256').update(value).digest('hex')
function data(html) {
  return JSON.parse(
    unpack(
      JSON.parse(html.match(/<script id="diagram-data"[^>]*>([\s\S]*?)<\/script>/)[1]).compressed,
    ),
  )
}
test('PC-I07 XML and bindings alone move/rename a block, field and wire and refresh derived hashes', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-layout-'))
  try {
    copyContent(content, temporary)
    const oldProfile = fs.readFileSync(path.join(temporary, 'processor_profile.json'), 'utf8')
    const edit = editDrawing(temporary),
      { ids } = edit
    assert.equal(
      fs.readFileSync(path.join(temporary, 'processor_profile.json'), 'utf8'),
      oldProfile,
      'The fixture edited a third input',
    )
    execFileSync(process.execPath, [builder, temporary], { stdio: 'pipe' })
    const xml = fs.readFileSync(path.join(temporary, 'diagram.drawio.xml'), 'utf8'),
      cells = graphCells(xml)
    assert.equal(
      Number(cells.get(ids.root).getElementsByTagName('mxGeometry')[0].getAttribute('x')),
      edit.rootX,
    )
    const profile = JSON.parse(
      fs.readFileSync(path.join(temporary, 'processor_profile.json'), 'utf8'),
    )
    assert.equal(profile.diagram_sha256, hash(xml))
    assert.equal(
      profile.bindings_sha256,
      hash(fs.readFileSync(path.join(temporary, 'diagram_bindings.json'))),
    )
    for (const name of ['explore', 'session']) {
      const html = fs.readFileSync(path.join(temporary, `viewer/${name}.html`), 'utf8'),
        prepared = data(html)
      assert.equal(unpack(prepared.xml), xml)
      assert.ok(prepared.blocks[ids.root])
      assert.equal(prepared.blocks[ids.sourceRoot], undefined)
      assert.equal(prepared.fields[ids.field].owner, ids.root)
      assert.equal(prepared.owners[ids.field], ids.root)
      assert.ok(prepared.connection_lookup[ids.edge].length)
      assert.ok(prepared.connections.some((connection) => connection.edges.includes(ids.edge)))
      assert.ok(prepared.pages.some((page) => page.components.includes(ids.root)))
      assert.equal(prepared.viewrv_refresh_cameras, true)
      assert.equal(
        hash(html.match(/<script id="drawio-runtime">([\s\S]*?)<\/script>/)[1]),
        hash(
          fs
            .readFileSync(path.join(content, 'viewer/index.html'), 'utf8')
            .match(/<script id="drawio-runtime">([\s\S]*?)<\/script>/)[1],
        ),
      )
    }
    const once = fs.readFileSync(path.join(temporary, 'viewer/generated.json'), 'utf8')
    execFileSync(process.execPath, [builder, temporary], { stdio: 'pipe' })
    assert.equal(
      fs.readFileSync(path.join(temporary, 'viewer/generated.json'), 'utf8'),
      once,
      'Rebuilding the same inputs was not deterministic',
    )
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true })
  }
})
test('PC-I07 dangling IDs and contradictory aliases reject a build before derived metadata is changed', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-layout-invalid-'))
  try {
    copyContent(content, temporary)
    const edit = editDrawing(temporary),
      file = path.join(temporary, 'diagram_bindings.json')
    const profile = fs.readFileSync(path.join(temporary, 'processor_profile.json'))
    const bindings = JSON.parse(fs.readFileSync(file, 'utf8'))
    delete bindings.cell_ids[edit.ids.sourceField]
    fs.writeFileSync(file, JSON.stringify(bindings))
    assert.throws(
      () => execFileSync(process.execPath, [builder, temporary], { stdio: 'pipe' }),
      (error) => String(error.stderr).includes('Referencia gráfica sin celda actual'),
    )
    assert.deepEqual(fs.readFileSync(path.join(temporary, 'processor_profile.json')), profile)
    bindings.cell_ids[edit.ids.sourceField] = edit.ids.field
    bindings.cell_ids[edit.ids.sourceRoot] = edit.ids.field
    fs.writeFileSync(file, JSON.stringify(bindings))
    assert.throws(
      () => execFileSync(process.execPath, [builder, temporary], { stdio: 'pipe' }),
      (error) => String(error.stderr).includes('Binding contradictorio'),
    )
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true })
  }
})
test('PC-I07 layout preparation rejects malformed geometry and rewiring presented as a layout-only change', () => {
  assert.throws(
    () =>
      graphCells(
        '<mxGraphModel><root><mxCell id="0"/><mxCell id="1" parent="0"><mxGeometry x="NaN"/></mxCell></root></mxGraphModel>',
      ),
    /coordenada inválida/,
  )
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-layout-rewire-'))
  try {
    copyContent(content, temporary)
    const edit = editDrawing(temporary),
      file = path.join(temporary, 'diagram.drawio.xml')
    const cells = graphCells(fs.readFileSync(file, 'utf8')),
      edge = cells.get(edit.ids.edge)
    const native = edge.tagName === 'mxCell' ? edge : edge.getElementsByTagName('mxCell')[0]
    native.setAttribute('target', native.getAttribute('target') === '1' ? '0' : '1')
    const { XMLSerializer } = require('@xmldom/xmldom')
    fs.writeFileSync(file, new XMLSerializer().serializeToString(edge.ownerDocument))
    assert.throws(
      () => execFileSync(process.execPath, [builder, temporary], { stdio: 'pipe' }),
      (error) => String(error.stderr).includes('Los extremos de una conexión cambiaron'),
    )
  } finally {
    fs.rmSync(temporary, { recursive: true, force: true })
  }
})
