const { execFileSync } = require('node:child_process')
const { resolve } = require('node:path')
const { checkGuiLicenses } = require('./check_gui_licenses.cjs')

module.exports = async (context) => {
  if (context.electronPlatformName !== 'linux') return
  const software = resolve(__dirname, '..')
  checkGuiLicenses(software, context.appOutDir)
  execFileSync(
    resolve(software, '.venv/bin/python'),
    [resolve(__dirname, 'licenses.py'), '--stage', context.appOutDir],
    { stdio: 'inherit' },
  )
  execFileSync(
    resolve(software, '.venv/bin/python'),
    [resolve(__dirname, 'stage_linux.py'), context.appOutDir],
    { stdio: 'inherit' },
  )
}
