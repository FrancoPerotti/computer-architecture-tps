// Observe an isolated production rebuild; never write to gui/out or alter a product.
const {
  readFileSync,
  writeFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  realpathSync,
} = require('node:fs')
const { resolve, dirname, relative, join, sep } = require('node:path')
const { pathToFileURL } = require('node:url')
const { createHash } = require('node:crypto')

const hash = (bytes) => createHash('sha256').update(bytes).digest('hex')
const software = resolve(__dirname, '..')
const gui = join(software, 'gui')

function packageOf(id) {
  const clean = id.replace(/^\0/, '').split('?')[0]
  if (!clean.includes('/node_modules/')) return null
  let directory = dirname(clean)
  while (directory.startsWith(gui + '/') && directory !== gui) {
    const file = join(directory, 'package.json')
    if (existsSync(file)) {
      const manifest = JSON.parse(readFileSync(file, 'utf8'))
      if (manifest.name && manifest.version)
        return {
          name: manifest.name,
          version: manifest.version,
          license: manifest.license,
          directory: relative(gui, directory),
          manifest_sha256: hash(readFileSync(file)),
        }
    }
    directory = dirname(directory)
  }
  return null
}

async function audit(output, product) {
  if (existsSync(output)) throw Error('Usar un directorio de evidencia nuevo.')
  let parent = dirname(output)
  while (!existsSync(parent)) parent = dirname(parent)
  const destination = resolve(realpathSync(parent), relative(parent, output))
  for (const protectedRoot of [gui, product]) {
    const root = realpathSync(protectedRoot)
    if (destination === root || destination.startsWith(root + sep))
      throw Error('La evidencia debe quedar fuera de la GUI y del producto.')
  }
  mkdirSync(output, { recursive: true })
  process.chdir(gui)
  const { resolveConfig } = await import(
    pathToFileURL(join(gui, 'node_modules/electron-vite/dist/index.js'))
  )
  const { build } = await import(pathToFileURL(join(gui, 'node_modules/vite/dist/node/index.js')))
  const asar = await import(pathToFileURL(join(gui, 'node_modules/@electron/asar/lib/asar.js')))
  const chunks = [],
    external = new Set()
  function observer(role) {
    return {
      name: 'viewrv-module-audit-' + role,
      generateBundle(_options, bundle) {
        for (const id of this.getModuleIds()) {
          if (this.getModuleInfo(id)?.isExternal) external.add(id)
        }
        for (const chunk of Object.values(bundle)) {
          if (chunk.type !== 'chunk') continue
          for (const name of [...chunk.imports, ...chunk.dynamicImports]) {
            if (!Object.hasOwn(bundle, name)) external.add(name)
          }
          chunks.push({
            role,
            file: chunk.fileName,
            imports: chunk.imports,
            dynamic_imports: chunk.dynamicImports,
            modules: Object.entries(chunk.modules).map(([id, info]) => ({
              id: id.startsWith(gui) ? relative(gui, id) : id,
              package: packageOf(id),
              rendered_length: info.renderedLength ?? null,
            })),
          })
        }
      },
    }
  }
  const resolved = await resolveConfig(
    { configFile: join(gui, 'electron.vite.config.ts'), build: { outDir: join(output, 'bundle') } },
    'build',
    'production',
  )
  for (const [role, config] of Object.entries(resolved.config)) {
    config.plugins = [...(config.plugins || []), observer(role)]
    if (role === 'renderer') {
      const original = config.worker?.plugins
      config.worker = {
        ...config.worker,
        plugins: () => [...(original ? original() : []), observer('renderer-worker')],
      }
    }
    await build(config)
  }
  const comparisons = []
  function visit(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name)
      if (entry.isDirectory()) visit(path)
      else {
        const name = relative(join(output, 'bundle'), path).replaceAll('\\', '/')
        const rebuilt = readFileSync(path)
        let original
        try {
          original = asar.extractFile(join(product, 'resources/app.asar'), 'out/' + name)
        } catch {}
        comparisons.push({
          path: name,
          sha256: hash(rebuilt),
          packaged_sha256: original ? hash(original) : null,
          matches: !!original && rebuilt.equals(original),
        })
      }
    }
  }
  visit(join(output, 'bundle'))
  const archive = join(product, 'resources/app.asar')
  const archivedFiles = asar
    .listPackage(archive)
    .filter((name) => {
      const entry = asar.statFile(archive, name.replace(/^\//, ''))
      return typeof entry.size === 'number'
    })
    .map((name) => name.replace(/^\//, ''))
  const unobservedOutputs = archivedFiles.filter(
    (name) => name.startsWith('out/') && !comparisons.some((entry) => 'out/' + entry.path === name),
  )
  const packages = new Map()
  for (const chunk of chunks) {
    for (const module of chunk.modules) {
      if (module.package) {
        const key = module.package.name + '@' + module.package.version
        const current = packages.get(key) || { ...module.package, rendered_length: 0 }
        current.rendered_length += module.rendered_length || 0
        packages.set(key, current)
      }
    }
  }
  const report = {
    schema_version: 1,
    kind: 'observed-build-modules',
    scope:
      'Production chunk metadata, including workers. Module membership is conservative; a zero rendered length does not prove a package is wholly absent.',
    product,
    packaged_asar_sha256: hash(readFileSync(join(product, 'resources/app.asar'))),
    byte_equivalent:
      comparisons.length > 0 &&
      !unobservedOutputs.length &&
      comparisons.every((entry) => entry.matches),
    unobserved_outputs: unobservedOutputs,
    archive_other_files: archivedFiles.filter((name) => !name.startsWith('out/')),
    outputs: comparisons,
    packages: [...packages.values()].sort((a, b) => a.name.localeCompare(b.name)),
    external: [...external].sort(),
    chunks,
  }
  writeFileSync(join(output, 'modules.json'), JSON.stringify(report, null, 2) + '\n')
  console.log(
    JSON.stringify({
      byte_equivalent: report.byte_equivalent,
      outputs: comparisons.length,
      chunks: chunks.length,
      packages: packages.size,
    }),
  )
  if (!report.byte_equivalent) process.exitCode = 1
}

if (require.main === module) {
  const [output, product] = process.argv.slice(2)
  if (!output || !product) throw Error('Uso: node audit_gui_modules.cjs EVIDENCIA_NUEVA PRODUCTO')
  audit(resolve(output), resolve(product)).catch((error) => {
    console.error(error)
    process.exitCode = 1
  })
}
module.exports = { packageOf }
