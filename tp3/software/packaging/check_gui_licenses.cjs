const { execFileSync } = require('node:child_process')
const { mkdtempSync, readFileSync } = require('node:fs')
const { resolve } = require('node:path')

function validateReport(report, lock) {
  if (!report.byte_equivalent || report.unobserved_outputs.length)
    throw Error('La atribución de GUI no corresponde a los bytes empaquetados.')
  if (report.archive_other_files.length !== 1 || report.archive_other_files[0] !== 'package.json')
    throw Error('El ASAR contiene archivos adicionales sin revisar sus licencias.')
  const expected = new Set(lock.gui_packages.map((item) => item.name + '@' + item.version))
  for (const item of report.packages) {
    if (!expected.has(item.name + '@' + item.version))
      throw Error('Falta revisar la licencia del módulo: ' + item.name + '@' + item.version)
  }
  if (report.external.some((name) => !lock.gui_external.includes(name)))
    throw Error('La GUI incorpora una dependencia externa no revisada.')
}

function checkGuiLicenses(software, product) {
  const lock = JSON.parse(readFileSync(resolve(software, 'packaging/licenses-linux.lock.json')))
  const evidence = mkdtempSync(resolve(software, 'build/gui-license-audit-'))
  execFileSync(
    process.execPath,
    [resolve(software, 'packaging/audit_gui_modules.cjs'), resolve(evidence, 'modules'), product],
    { stdio: 'inherit' },
  )
  validateReport(JSON.parse(readFileSync(resolve(evidence, 'modules/modules.json'))), lock)
  return evidence
}

module.exports = { checkGuiLicenses, validateReport }
