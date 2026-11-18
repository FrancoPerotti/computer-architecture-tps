// electron-builder resolves hook modules inside the GUI workspace.
exports.beforePack = require('../../packaging/check_package.cjs')
exports.afterPack = require('../../packaging/stage_linux.cjs')
