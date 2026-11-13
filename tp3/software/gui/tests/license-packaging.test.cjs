const test = require('node:test')
const assert = require('node:assert/strict')
const { validateReport } = require('../../packaging/check_gui_licenses.cjs')

test('license attribution refuses an unreviewed module, external import or loose dependency', () => {
  const report = {
    byte_equivalent: true,
    unobserved_outputs: [],
    archive_other_files: ['package.json'],
    packages: [{ name: 'reviewed', version: '1.0.0' }],
    external: ['electron'],
  }
  const lock = { gui_packages: report.packages, gui_external: ['electron'] }
  assert.doesNotThrow(() => validateReport(report, lock))
  for (const change of [
    { byte_equivalent: false },
    { packages: [{ name: 'unreviewed', version: '1.0.0' }] },
    { external: ['unreviewed-native-module'] },
    { archive_other_files: ['package.json', 'node_modules/unreviewed/index.js'] },
    { unobserved_outputs: ['out/extra.js'] },
  ])
    assert.throws(() => validateReport({ ...report, ...change }, lock))
})
