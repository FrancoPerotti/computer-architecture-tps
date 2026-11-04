// Layout/ID edits in a private resource copy. No edits to approved source assets.
const fs = require('node:fs')
const path = require('node:path')
const zlib = require('node:zlib')
const { DOMParser, XMLSerializer } = require('@xmldom/xmldom')
const unpack = (value) =>
  decodeURIComponent(zlib.inflateRawSync(Buffer.from(value, 'base64')).toString())
const pack = (value) =>
  zlib.deflateRawSync(Buffer.from(encodeURIComponent(value))).toString('base64')
function copyContent(content, destination) {
  const manifest = JSON.parse(fs.readFileSync(path.join(content, 'viewer/generated.json'), 'utf8'))
  for (const name of [...Object.keys(manifest.inputs), 'viewer/provenance.json']) {
    const target = path.join(destination, name)
    fs.mkdirSync(path.dirname(target), { recursive: true })
    fs.copyFileSync(path.join(content, name), target)
  }
}
function editDrawing(content) {
  const read = (name) => fs.readFileSync(path.join(content, name), 'utf8')
  const bindings = JSON.parse(read('diagram_bindings.json'))
  const sourceHTML = read('viewer/index.html'),
    packed = JSON.parse(sourceHTML.match(/<script id="diagram-data"[^>]*>([\s\S]*?)<\/script>/)[1])
  const sourceData = JSON.parse(unpack(packed.compressed))
  const block = 'latch.if_id',
    sourceRoot = bindings.source_blocks[block],
    oldRoot = bindings.blocks[block]
  const sourceField = Object.keys(sourceData.fields).find(
    (id) => sourceData.fields[id].owner === sourceRoot,
  )
  const sourceEdge = sourceData.connections.find(
    (connection) =>
      connection.source_block === sourceRoot || connection.target_block === sourceRoot,
  ).edges[0]
  const oldField = bindings.cell_ids[sourceField] || sourceField,
    oldEdge = bindings.cell_ids[sourceEdge] || sourceEdge
  const ids = {
    block,
    root: 'viewrv-layout-if-id',
    field: 'viewrv-layout-field',
    edge: 'viewrv-layout-wire',
    sourceRoot,
    sourceField,
    sourceEdge,
  }
  const aliases = new Map([
    [oldRoot, ids.root],
    [oldField, ids.field],
    [oldEdge, ids.edge],
  ])
  const parser = new DOMParser(),
    outer = parser.parseFromString(read('diagram.drawio.xml'), 'text/xml'),
    diagram = outer.getElementsByTagName('diagram')[0]
  let model = diagram.getElementsByTagName('mxGraphModel')[0]
  if (!model)
    model = parser.parseFromString(unpack(diagram.textContent), 'text/xml').documentElement
  const elements = Array.from(model.getElementsByTagName('*'))
  const root = elements.find((node) => node.getAttribute('id') === oldRoot),
    rootGeometry = root.getElementsByTagName('mxGeometry')[0]
  // The approved drawing stores latch fields as separate vertices. Author the
  // whole module move in XML; the production adapter never invents this move.
  const moving = new Set(
    Object.entries(sourceData.owners)
      .filter(([, owner]) => owner === sourceRoot)
      .map(([id]) => (id === sourceRoot ? oldRoot : bindings.cell_ids[id] || id)),
  )
  for (const element of elements) {
    if (!moving.has(element.getAttribute('id'))) continue
    const native =
      element.tagName === 'mxCell' ? element : element.getElementsByTagName('mxCell')[0]
    if (
      !native ||
      native.getAttribute('vertex') !== '1' ||
      moving.has(native.getAttribute('parent'))
    )
      continue
    const geometry = element.getElementsByTagName('mxGeometry')[0]
    if (geometry) geometry.setAttribute('x', String(Number(geometry.getAttribute('x')) + 8000))
  }
  const rootX = Number(rootGeometry.getAttribute('x')),
    rootY = Number(rootGeometry.getAttribute('y'))
  const edge = elements.find((node) => node.getAttribute('id') === oldEdge),
    edgeGeometry = edge.getElementsByTagName('mxGeometry')[0]
  const point = edgeGeometry.getElementsByTagName('mxPoint')[0]
  if (!point) throw Error('The chosen approved wire has no authored point')
  point.setAttribute('x', String(Number(point.getAttribute('x')) + 123))
  point.setAttribute('y', String(Number(point.getAttribute('y')) - 57))
  for (const element of elements)
    for (const attribute of Array.from(element.attributes))
      if (aliases.has(attribute.value))
        element.setAttribute(attribute.name, aliases.get(attribute.value))
  const serializer = new XMLSerializer()
  while (diagram.firstChild) diagram.removeChild(diagram.firstChild)
  diagram.appendChild(outer.createTextNode(pack(serializer.serializeToString(model))))
  fs.writeFileSync(path.join(content, 'diagram.drawio.xml'), serializer.serializeToString(outer))
  bindings.blocks[block] = ids.root
  bindings.cell_ids[sourceField] = ids.field
  bindings.cell_ids[sourceEdge] = ids.edge
  fs.writeFileSync(
    path.join(content, 'diagram_bindings.json'),
    JSON.stringify(bindings, null, 2) + '\n',
  )
  return {
    ids,
    rootX,
    rootY,
    point: { x: Number(point.getAttribute('x')), y: Number(point.getAttribute('y')) },
  }
}
module.exports = { copyContent, editDrawing, unpack }
