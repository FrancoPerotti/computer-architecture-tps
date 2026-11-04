// Native runtime check only. The production builder still requires the real bitstream.
const {
  cpSync,
  existsSync,
  lstatSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  writeFileSync,
} = require('node:fs')
const { basename, dirname, join, resolve } = require('node:path')
const { pathToFileURL } = require('node:url')
const { createHash } = require('node:crypto')
const { execFileSync } = require('node:child_process')
const { checkGuiLicenses } = require('./check_gui_licenses.cjs')
const hash = (file) => createHash('sha256').update(readFileSync(file)).digest('hex')

function inventory(root, directory = '') {
  return readdirSync(join(root, directory))
    .sort()
    .flatMap((name) => {
      const relative = directory ? `${directory}/${name}` : name
      const file = join(root, relative),
        stat = lstatSync(file)
      if (stat.isSymbolicLink())
        throw Error('El paquete contiene un enlace no resuelto: ' + relative)
      if (stat.isDirectory()) return inventory(root, relative)
      if (!stat.isFile()) throw Error('Tipo de archivo no admitido: ' + relative)
      return [
        {
          path: relative,
          size: stat.size,
          mode: stat.mode & 0o7777,
          sha256: hash(file),
        },
      ]
    })
}

async function buildVerification(software, { archive = false } = {}) {
  if (process.platform !== 'linux' || process.arch !== 'x64')
    throw Error('Esta comprobación requiere Linux x86_64.')
  const version = JSON.parse(readFileSync(resolve(software, 'gui/package.json'), 'utf8')).version
  const stage = mkdtempSync(resolve(software, `build/native-gui-${version}-`))
  const appSource = mkdtempSync(resolve(software, 'build/gui-asar-source-'))
  const archivePath = stage + '.tar.gz'
  try {
    const copy = (from, to) => cpSync(from, to, { recursive: true, dereference: true })
    copy(resolve(software, 'gui/node_modules/electron/dist'), stage)
    renameSync(resolve(stage, 'electron'), resolve(stage, 'viewrv-gui'))
    copy(resolve(software, 'build/python/viewrv'), stage)
    copy(resolve(software, 'build/python/viewrv-core'), resolve(stage, 'resources/core'))
    for (const directory of ['content', 'hardware', 'programmer'])
      copy(resolve(software, 'resources', directory), resolve(stage, 'resources', directory))
    copy(resolve(software, 'gui/out'), resolve(appSource, 'out'))
    copy(resolve(software, 'gui/package.json'), resolve(appSource, 'package.json'))
    const asar = await import(
      pathToFileURL(resolve(software, 'gui/node_modules/@electron/asar/lib/asar.js'))
    )
    await asar.createPackage(appSource, resolve(stage, 'resources/app.asar'))
    checkGuiLicenses(software, stage)
    execFileSync(
      resolve(software, '.venv/bin/python'),
      [resolve(software, 'packaging/licenses.py'), '--stage', stage],
      { stdio: 'inherit' },
    )
    if (
      existsSync(resolve(stage, 'release.json')) ||
      existsSync(resolve(stage, 'resources/hardware/processor.bit'))
    )
      throw Error(
        'Esta construcción de verificación requiere el estado sin bitstream; usá el constructor de distribución para hardware.',
      )
    writeFileSync(
      resolve(stage, 'VERIFICATION-ONLY.txt'),
      'Paquete Linux de verificación: Electron/ASAR, CLI/core nativos y recursos locales.\n' +
        'Sin bitstream aprobado ni release.json. No constituye la distribución final de hardware.\n' +
        'Extraé el archivo completo y ejecutá ./viewrv-gui; la CLI está en ./viewrv.\n',
    )
    execFileSync(
      resolve(software, '.venv/bin/python'),
      [resolve(software, 'packaging/stage_linux.py'), stage],
      { stdio: 'inherit' },
    )
    const executables = ['viewrv-gui', 'viewrv', 'resources/core/viewrv-core', 'resources/app.asar']
    writeFileSync(
      resolve(stage, 'verification-sha256.json'),
      JSON.stringify(
        Object.fromEntries(executables.map((name) => [name, hash(resolve(stage, name))])),
        null,
        2,
      ) + '\n',
    )
    const repo = resolve(software, '../..')
    const sourceCommit = execFileSync('git', ['rev-parse', 'HEAD'], {
      cwd: repo,
      encoding: 'utf8',
    }).trim()
    const sourceDirty = !!execFileSync('git', ['status', '--porcelain', '--', 'tp3/software'], {
      cwd: repo,
      encoding: 'utf8',
    }).trim()
    const files = inventory(stage)
    const manifest = {
      schema_version: 1,
      kind: 'verification-only',
      app_version: version,
      platform: 'linux',
      architecture: 'x86_64',
      source_commit: sourceCommit,
      source_dirty: sourceDirty,
      node_build_version: process.version,
      electron_version: JSON.parse(
        readFileSync(resolve(software, 'gui/node_modules/electron/package.json')),
      ).version,
      locks: Object.fromEntries(
        [
          '.python-version',
          'requirements-linux.lock',
          'gui/.node-version',
          'gui/package-lock.json',
        ].map((name) => [name, hash(resolve(software, name))]),
      ),
      licenses: files
        .filter((file) => /license|notice|copyright|ofl/i.test(file.path))
        .map((file) => file.path),
      files,
    }
    writeFileSync(
      resolve(stage, 'verification-manifest.json'),
      JSON.stringify(manifest, null, 2) + '\n',
    )
    let result = {
      stage,
      manifest: resolve(stage, 'verification-manifest.json'),
    }
    if (archive) {
      const archiveRoot = `viewrv-${version}-linux-x64-verification`
      const escaped = basename(stage).replace(/[.]/g, '\\.')
      execFileSync('tar', [
        '--sort=name',
        '--mtime=@0',
        '--owner=0',
        '--group=0',
        '--numeric-owner',
        `--transform=s,^${escaped},${archiveRoot},`,
        '-czf',
        archivePath,
        '-C',
        dirname(stage),
        basename(stage),
      ])
      const digest = hash(archivePath)
      writeFileSync(archivePath + '.sha256', `${digest}  ${basename(archivePath)}\n`)
      result = {
        ...result,
        archive: archivePath,
        archive_root: archiveRoot,
        sha256: digest,
      }
    }
    return result
  } catch (error) {
    rmSync(stage, { recursive: true, force: true })
    rmSync(archivePath, { force: true })
    rmSync(archivePath + '.sha256', { force: true })
    throw error
  } finally {
    rmSync(appSource, { recursive: true, force: true })
  }
}

if (require.main === module) {
  const args = process.argv.slice(2)
  if (
    args.some((arg) => arg.startsWith('--') && arg !== '--archive') ||
    args.filter((arg) => !arg.startsWith('--')).length > 1
  )
    throw Error('Uso: node build_gui_verification.cjs [directorio-software] [--archive]')
  const software = resolve(args.find((arg) => !arg.startsWith('--')) || resolve(__dirname, '..'))
  buildVerification(software, { archive: args.includes('--archive') })
    .then((result) =>
      console.log(args.includes('--archive') ? JSON.stringify(result, null, 2) : result.stage),
    )
    .catch((error) => {
      console.error(error)
      process.exitCode = 1
    })
}
module.exports = { buildVerification, inventory }
