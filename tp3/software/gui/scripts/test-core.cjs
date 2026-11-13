const { spawnSync } = require('node:child_process')
const { resolve } = require('node:path')

const software = resolve(__dirname, '../..')
const python = resolve(
  software,
  '.venv',
  process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python',
)
const result = spawnSync(
  python,
  ['-m', 'unittest', 'discover', '-s', 'software/tests/viewrv', '-t', '.', '-v'],
  {
    cwd: resolve(software, '..'),
    stdio: 'inherit',
  },
)
if (result.error) console.error(result.error.message)
process.exitCode = result.status ?? 1
