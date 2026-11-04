// A hardware package must never reuse a stale inventory or omit its real bitstream.
const fs = require('node:fs')
const path = require('node:path')
const crypto = require('node:crypto')
const { execFileSync } = require('node:child_process')
async function checkHardware(context) {
  const software = path.resolve(context.packager.projectDir, '..')
  const pkg = JSON.parse(fs.readFileSync(path.join(software, 'gui/package.json'), 'utf8'))
  const release = JSON.parse(
    fs.readFileSync(path.join(software, 'build/stage-release.json'), 'utf8'),
  )
  if (release.app_version !== pkg.version)
    throw new Error('El inventario pertenece a otra versión del producto.')
  const target = context.electronPlatformName === 'win32' ? 'windows' : context.electronPlatformName
  if (target && release.platform !== target)
    throw new Error(
      'El runtime Python y el destino Electron deben pertenecer a la misma plataforma nativa.',
    )
  for (const required of ['programmer', 'bitstream'])
    if (!release.resources.some((item) => item.role === required))
      throw new Error(`Falta el recurso obligatorio ${required}.`)
  if (!release.resources.some((item) => item.path === 'resources/hardware/processor.bit'))
    throw new Error('Falta el bitstream real de TP3.')
  for (const item of release.resources.filter((item) =>
    ['programmer', 'bitstream'].includes(item.role),
  )) {
    const file = path.resolve(software, item.path)
    if (!file.startsWith(path.join(software, 'resources') + path.sep))
      throw new Error('Recurso fuera de la entrega.')
    const actual = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')
    if (actual !== item.sha256) throw new Error(`Cambió la huella del recurso ${item.path}.`)
  }
  return { software, target }
}
module.exports = async (context) => {
  const { software, target } = await checkHardware(context)
  if (target !== 'linux')
    throw new Error('Falta revisar el material de licencias de la distribución Windows.')
  if (!fs.existsSync(path.join(software, 'packaging/licenses-linux.lock.json')))
    throw new Error('Falta preparar el material de licencias de distribución.')
  execFileSync(
    path.join(software, '.venv/bin/python'),
    [path.join(software, 'packaging/licenses.py')],
    { stdio: 'inherit' },
  )
}
module.exports.checkHardware = checkHardware
