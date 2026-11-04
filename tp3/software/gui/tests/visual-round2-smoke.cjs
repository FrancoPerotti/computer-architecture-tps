// Second visual review, comments 1–8: actual renderer and isolated core; no hardware acceptance.
const { _electron: electron } = require(process.env.PLAYWRIGHT_MODULE || 'playwright')
const { spawn } = require('node:child_process')
const { mkdtempSync, existsSync, rmSync, readFileSync } = require('node:fs')
const { tmpdir } = require('node:os')
const { resolve } = require('node:path')
const assert = require('node:assert/strict')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')
const gui = resolve(__dirname, '..'),
  tp3 = resolve(gui, '../..'),
  root = mkdtempSync(resolve(tmpdir(), 'viewrv-visual-round2-'))
const env = {
  ...process.env,
  PYTHONPATH: tp3,
  XDG_RUNTIME_DIR: root,
  XDG_STATE_HOME: resolve(root, 'state'),
  XDG_CONFIG_HOME: resolve(root, 'config'),
  XDG_DATA_HOME: resolve(root, 'data'),
  VIEWRV_TEST_CONTROL: root,
}
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
async function until(predicate, timeout = 10000) {
  const end = Date.now() + timeout
  while (Date.now() < end) {
    try {
      if (await predicate()) return
    } catch {}
    await delay(30)
  }
  throw Error('Visual condition timed out')
}
;(async () => {
  const core = spawn(
    resolve(gui, '../.venv/bin/python'),
    ['-m', 'software.tests.viewrv.session_core'],
    { cwd: tp3, env, stdio: ['ignore', 'ignore', 'pipe'] },
  )
  let instance, page
  try {
    await until(() => existsSync(resolve(root, 'viewrv/core.json')))
    instance = await electron.launch({
      executablePath: resolve(gui, 'node_modules/electron/dist/electron'),
      args: [
        gui,
        '--disable-gpu',
        '--ozone-platform=x11',
        `--user-data-dir=${resolve(root, 'profile')}`,
      ],
      env,
    })
    page = await instance.firstWindow()
    await page.setViewportSize({ width: 1301, height: 639 })
    const errors = []
    page.on('pageerror', (error) => errors.push(String(error)))
    await page.getByLabel('viewrv', { exact: true }).waitFor()
    await openConnection(page)
    const connection = page.getByRole('dialog', { name: 'Conexión con la placa', exact: true })
    await connection.getByRole('heading', { name: 'Destinos de conexión', exact: true }).waitFor()
    assert.equal(
      await connection
        .getByRole('button', { name: 'Preparar Basys 3', exact: true })
        .evaluate((n) => getComputedStyle(n).backgroundColor),
      'rgb(67, 56, 202)',
    )
    await page.screenshot({ path: resolve(gui, '../build/visual-round2-connection.png') })
    await closeConnection(page)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    async function openExample(name = 'Sumar dos números') {
      await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
      const dialog = page.getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
      await dialog.getByText('59 de 59 ejemplos', { exact: true }).waitFor()
      const centered = await dialog.getByLabel('Buscar ejemplo', { exact: true }).evaluate((n) => {
        const a = n.getBoundingClientRect(),
          b = n.parentElement.querySelector('svg').getBoundingClientRect()
        return (
          Math.abs((a.top + a.bottom - b.top - b.bottom) / 2) < 1 &&
          b.left > a.left + 5 &&
          b.right < a.left + 30
        )
      })
      assert.ok(centered, 'Search icon is off-center or overlaps text')
      const filename = await dialog
        .getByRole('button', { name, exact: true })
        .locator('code')
        .innerText()
      await dialog.getByRole('button', { name, exact: true }).click()
      await page.getByRole('tab', { name: filename, exact: true }).waitFor()
      await page.getByRole('button', { name: 'Acerca del ejemplo', exact: true }).waitFor()
      return filename
    }
    async function recovery() {
      await menuCommand(page, 'Ver', 'Borradores recuperables…')
      return page.getByRole('dialog', { name: 'Borradores recuperables', exact: true })
    }
    async function closeDialog(dialog) {
      await dialog.getByRole('button', { name: 'Cerrar diálogo', exact: true }).click()
    }
    for (const name of ['Sumar dos números', 'Sumar dos números', 'BNE: salto no tomado']) {
      const filename = await openExample(name)
      await page.getByRole('tab', { name: filename, exact: true }).getByTitle('Cerrar tab').click()
      await until(() =>
        page
          .getByRole('tab')
          .count()
          .then((n) => n === 0),
      )
    }
    let drafts = await recovery()
    await drafts.getByText('No hay borradores pendientes de recuperar.', { exact: true }).waitFor()
    await closeDialog(drafts)
    await openExample()
    const tab = page.getByRole('tab', { name: 'addition.s', exact: true })
    const input = page.locator('.monaco-editor:visible [role="textbox"]').first()
    const editor = page.locator('.monaco-editor:visible').first()
    const t = await tab.boundingBox(),
      e = await editor.boundingBox(),
      info = await page
        .getByRole('button', { name: 'Acerca del ejemplo', exact: true })
        .boundingBox()
    assert.ok(e.y - t.y - t.height < 16, 'Example metadata still consumes a header row')
    assert.ok(
      info.y > e.y + e.height - 50 && info.x > e.x + e.width - 60,
      'Info is not in the editor corner',
    )
    const run = page.getByRole('group', { name: 'Ejecutar programa', exact: true })
    assert.ok(
      await run.evaluate((n) => {
        const s = getComputedStyle(n)
        return (
          s.backgroundColor === 'rgba(0, 0, 0, 0)' &&
          s.borderTopWidth === '0px' &&
          n.getBoundingClientRect().width <= 52
        )
      }),
      'Run group is boxed or too wide',
    )
    await page.locator('.monaco-editor:visible .view-line').nth(1).hover()
    await page.locator('.viewrv-hover-margin').waitFor()
    await page.locator('.viewrv-hover-line-number').waitFor()
    const hover = await page.evaluate(() => {
      const a = document.querySelector('.viewrv-hover-line').getBoundingClientRect(),
        b = document.querySelector('.viewrv-hover-margin').getBoundingClientRect()
      return (
        Math.abs(a.y - b.y) < 1 &&
        getComputedStyle(document.querySelector('.viewrv-hover-line')).backgroundColor ===
          getComputedStyle(document.querySelector('.viewrv-hover-margin')).backgroundColor
      )
    })
    assert.ok(hover, 'Hover does not cover both text and gutter on the same line')
    await page.screenshot({ path: resolve(gui, '../build/visual-round2-editor.png') })
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await page.getByText('Programa ensamblado', { exact: true }).waitFor()
    await page.getByRole('button', { name: 'Ver ensamblado', exact: true }).click()
    await page.getByRole('heading', { name: 'Vista ensamblada', exact: true }).waitFor()
    assert.deepEqual(await page.getByRole('columnheader').allTextContents(), [
      'PC',
      'Línea',
      'Instrucción fuente',
      'Palabra de máquina',
    ])
    const first = page.locator('tbody tr').first()
    assert.deepEqual(await first.getByRole('cell').allTextContents(), [
      '0x00000000',
      '2',
      'addi x1, x0, 8',
      '0x00800093',
    ])
    await page.screenshot({ path: resolve(gui, '../build/visual-round2-assembly.png') })
    await tab.click()
    await input.focus()
    await page.keyboard.press('Control+End')
    await page.keyboard.insertText('# conservar esta variante\n')
    await page.getByText('Ensamblado anterior', { exact: true }).waitFor()
    assert.equal(
      await editor.boundingBox().then((r) => r.y),
      e.y,
      'Stale assembly message pushes source down',
    )
    await page
      .getByRole('tab', { name: 'addition.s ●', exact: true })
      .getByTitle('Cerrar tab')
      .click()
    await page.getByRole('tab', { name: 'addition.s ●', exact: true }).waitFor({ state: 'hidden' })
    await page.reload()
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    drafts = await recovery()
    await until(() =>
      drafts
        .getByRole('button', { name: /^Recuperar / })
        .count()
        .then((n) => n === 1),
    )
    assert.equal(
      await drafts.getByRole('button', { name: 'Recuperar addition.s', exact: true }).count(),
      1,
    )
    assert.equal(await drafts.getByRole('button', { name: /^Recuperar / }).count(), 1)
    await page.screenshot({ path: resolve(gui, '../build/visual-round2-recovery.png') })
    await drafts.getByRole('button', { name: 'Recuperar addition.s', exact: true }).click()
    await until(() =>
      page
        .locator('.monaco-editor:visible .view-lines')
        .innerText()
        .then((t) => t.replace(/\s/g, ' ').includes('conservar esta variante')),
    )
    const restored = page.locator('.monaco-editor:visible [role="textbox"]').first()
    for (const width of [1528, 1301, 615]) {
      await page.setViewportSize({ width, height: width === 1528 ? 771 : 639 })
      await restored.focus()
      await page.keyboard.press('Control+a')
      await page.keyboard.type('lui')
      await page.keyboard.press('Control+Space')
      const docs = page.locator('.suggest-details .docs:visible')
      await docs.waitFor()
      await until(() => docs.innerText().then((t) => t.includes('20 bits')))
      assert.equal(
        await page.locator('.suggest-details [role="button"]:visible').count(),
        0,
        'Documentation exposes a close button',
      )
      const metrics = await docs.evaluate((n) => {
        const body = n.parentElement,
          p = n.closest('.suggest-details'),
          r = n.getBoundingClientRect()
        return {
          height: body.clientHeight,
          scroll: body.scrollHeight,
          width: body.clientWidth,
          scrollWidth: body.scrollWidth,
          fullyVisible:
            r.bottom <= p.getBoundingClientRect().bottom + 1 && r.right <= window.innerWidth + 1,
        }
      })
      assert.ok(metrics.fullyVisible, JSON.stringify(metrics))
      assert.ok(
        metrics.scroll <= metrics.height + 1 && metrics.scrollWidth <= metrics.width + 1,
        'Unnecessary documentation scrollbar: ' + JSON.stringify(metrics),
      )
      await page.keyboard.press('Control+Space')
      assert.equal(await docs.isVisible(), true, 'Documentation can be closed independently')
      await page.screenshot({
        path: resolve(gui, `../build/visual-round2-completion-${width}.png`),
      })
      await page.keyboard.press('Escape')
    }
    assert.deepEqual(errors, [])
    console.log(
      'Round 2 visual feedback passed: unboxed compact Run, gutter/text hover, connection styling, pinned completion docs without redundant scroll at 1528/1301/615, centered search, untouched examples excluded from recovery, changed source recovered intact, corner info and compact stale indication, dedicated source-line column. Real Electron/core in an isolated profile.',
    )
  } catch (e) {
    if (page && !page.isClosed())
      await page
        .screenshot({ path: resolve(gui, '../build/visual-round2-failure.png') })
        .catch(() => {})
    throw e
  } finally {
    if (instance) {
      await instance.evaluate(({ app }) => app.exit()).catch(() => {})
      await instance.close().catch(() => {})
    }
    if (core.exitCode === null && core.signalCode === null) core.kill('SIGTERM')
    await new Promise((resolve) =>
      core.exitCode !== null || core.signalCode !== null ? resolve() : core.once('exit', resolve),
    )
    rmSync(root, { recursive: true, force: true })
  }
})().catch((e) => {
  console.error(e)
  process.exitCode = 1
})
