const { test } = require('node:test')
const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const os = require('node:os')
const { createHash } = require('node:crypto')
const check = require('../../packaging/check_package.cjs')
const { inventory } = require('../../packaging/build_gui_verification.cjs')

test('verification inventory records nested file contents and permissions and rejects links outside the package', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-verification-inventory-'))
  try {
    fs.mkdirSync(path.join(root, 'resources'))
    const bytes = Buffer.from([0, 255, 13, 10])
    fs.writeFileSync(path.join(root, 'resources/core'), bytes, { mode: 0o755 })
    fs.writeFileSync(path.join(root, 'LICENSE'), 'license')
    const files = inventory(root)
    assert.deepEqual(
      files.map((file) => file.path),
      ['LICENSE', 'resources/core'],
    )
    assert.deepEqual(files[1], {
      path: 'resources/core',
      size: bytes.length,
      mode: 0o755,
      sha256: createHash('sha256').update(bytes).digest('hex'),
    })
    fs.writeFileSync(path.join(root, 'resources/core'), 'altered')
    assert.notEqual(inventory(root)[1].sha256, files[1].sha256)
    fs.symlinkSync('../outside', path.join(root, 'external'))
    assert.throws(() => inventory(root), /enlace no resuelto/)
  } finally {
    fs.rmSync(root, { recursive: true, force: true })
  }
})

test('PC-I04 packaging rejects missing hardware, stale inventories, cross-platform bundles and altered resources', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'viewrv-package-gate-'))
  const json = (file, value) => fs.writeFileSync(path.join(root, file), JSON.stringify(value))
  try {
    for (const dir of ['gui', 'build', 'resources/hardware', 'resources/programmer'])
      fs.mkdirSync(path.join(root, dir), { recursive: true })
    json('gui/package.json', { version: 'test' })
    const release = { app_version: 'test', platform: 'linux', resources: [] }
    const context = {
      packager: { projectDir: path.join(root, 'gui') },
      electronPlatformName: 'linux',
    }
    json('build/stage-release.json', release)
    await assert.rejects(check(context), /programmer/)
    for (const [role, file] of [
      ['programmer', 'resources/programmer/openFPGALoader'],
      ['bitstream', 'resources/hardware/processor.bit'],
    ]) {
      fs.writeFileSync(path.join(root, file), 'test-only gate fixture')
      release.resources.push({
        role,
        path: file,
        sha256: createHash('sha256').update('test-only gate fixture').digest('hex'),
      })
    }
    json('build/stage-release.json', release)
    await check(context)
    await assert.rejects(check({ ...context, electronPlatformName: 'win32' }), /plataforma/)
    json('build/stage-release.json', { ...release, app_version: 'old' })
    await assert.rejects(check(context), /otra versión/)
    json('build/stage-release.json', release)
    fs.writeFileSync(path.join(root, 'resources/hardware/processor.bit'), 'changed')
    await assert.rejects(check(context), /huella/)
  } finally {
    fs.rmSync(root, { recursive: true, force: true })
  }
})
