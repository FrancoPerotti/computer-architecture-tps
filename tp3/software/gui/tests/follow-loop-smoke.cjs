// TEST-PC-018: repeated PCs remain distinct in the actual source/diagram UI.
const { withGuiEnvironment, until: waitUntil } = require('./gui-fixture.cjs')
const { openConnection, closeConnection } = require('./ui-commands.cjs')
const fs = require('node:fs'),
  path = require('node:path'),
  assert = require('node:assert/strict')
const { menuCommand } = require('./ui-commands.cjs')
const until = (predicate, timeout = 20000) => waitUntil(predicate, timeout)

withGuiEnvironment(
  'follow-loop',
  async ({ root, gui, launch }) => {
    const source = path.join(root, 'loop.s')
    fs.copyFileSync(path.resolve(gui, '../resources/content/examples/loop-self.s'), source)
    const steps = () =>
      fs
        .readFileSync(path.join(root, 'uart.tx'), 'utf8')
        .split('\n')
        .filter((line) => line === '03').length
    let { instance, page, errors } = await launch({
      viewport: { width: 1440, height: 1000 },
      gpu: true,
    })
    await openConnection(page)
    await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
    await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
    await closeConnection(page)
    await instance.evaluate(({ dialog }, source) => {
      dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [source] })
    }, source)
    await page.getByRole('button', { name: 'IDE', exact: true }).click()
    await menuCommand(page, 'Archivo', 'Abrir programa…')
    await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Cargar', exact: true }).click()
    await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
    await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
    await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
    const diagram = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true }),
      inspector = diagram.getByRole('region', { name: 'Inspector del circuito', exact: true })
    const element = await page.locator('iframe[title="Diagrama de la sesión"]').elementHandle(),
      frame = await element.contentFrame()
    await until(() => frame.evaluate(() => !!window.tp3SessionAdapter))
    async function step(cycle) {
      await until(() =>
        page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled(),
      )
      await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
      await diagram.getByText(`Ciclo observado · ${cycle}`, { exact: true }).waitFor()
      assert.equal(steps(), cycle)
    }
    const component = inspector.getByLabel('Componente del circuito', { exact: true })
    await step(1)
    await component.selectOption('latch.if_id')
    await inspector.getByRole('button', { name: 'Seguir esta instrucción', exact: true }).click()
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    for (const [cycle, block] of [
      [2, 'latch.id_ex'],
      [3, 'latch.ex_mem'],
      [4, 'latch.mem_wb'],
    ]) {
      await step(cycle)
      await until(async () => (await component.inputValue()) === block)
    }
    await page.getByRole('tab', { name: /loop.s/ }).click()
    await page.locator('.monaco-editor:visible [role="textbox"]').first().focus()
    await page.keyboard.press('Control+Home')
    await page.keyboard.press('ArrowDown')
    await page.keyboard.press('Control+Alt+F9')
    const appearances = page.getByRole('dialog', { name: 'Apariciones de la línea 2', exact: true })
    await appearances.getByRole('button', { name: 'Seleccionar IF/ID', exact: true }).waitFor()
    await appearances.getByRole('button', { name: 'Seleccionar MEM/WB', exact: true }).waitFor()
    assert.equal(await appearances.getByRole('button', { name: /^Seleccionar / }).count(), 2)
    await page.keyboard.press('Escape')
    assert.equal(await component.inputValue(), 'latch.mem_wb')
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    assert.equal(steps(), 4)
    await page
      .getByRole('button', { name: 'Seguir instrucción de la línea 2', exact: true })
      .click()
    const choices = page.getByRole('dialog', { name: 'Apariciones de la línea 2', exact: true })
    await choices.getByRole('button', { name: 'Seguir en IF/ID', exact: true }).waitFor()
    await choices.getByRole('button', { name: 'Seguir en MEM/WB', exact: true }).click()
    assert.equal(await component.inputValue(), 'latch.mem_wb')
    await page.screenshot({
      path: path.resolve(gui, '../build/gui-pc-i07-loop-two-occurrences.png'),
    })
    const camera = await frame.evaluate(() => {
      const g = window.tp3Viewer.viewer.graph
      return {
        scale: g.view.scale,
        x:
          (g.container.scrollLeft + g.container.clientWidth / 2) / g.view.scale -
          g.view.translate.x,
        y:
          (g.container.scrollTop + g.container.clientHeight / 2) / g.view.scale -
          g.view.translate.y,
      }
    })
    await step(5)
    await inspector.getByText('La aparición terminó su recorrido.', { exact: true }).waitFor()
    assert.equal(await component.inputValue(), 'latch.mem_wb')
    assert.equal(await page.locator('.viewrv-selected-occurrence-line:visible').count(), 0)
    const after = await frame.evaluate(() => {
      const g = window.tp3Viewer.viewer.graph
      return {
        scale: g.view.scale,
        x:
          (g.container.scrollLeft + g.container.clientWidth / 2) / g.view.scale -
          g.view.translate.x,
        y:
          (g.container.scrollTop + g.container.clientHeight / 2) / g.view.scale -
          g.view.translate.y,
      }
    })
    assert.equal(after.scale, camera.scale)
    assert.ok(
      Math.abs(after.x - camera.x) < 2 / camera.scale &&
        Math.abs(after.y - camera.y) < 2 / camera.scale,
      'Retirement moved the camera world centre',
    )
    await step(6)
    await inspector.getByText('La aparición terminó su recorrido.', { exact: true }).waitFor()
    assert.equal(await component.inputValue(), 'latch.mem_wb')
    assert.equal(await page.locator('.viewrv-selected-occurrence-line:visible').count(), 0)
    await page
      .getByRole('button', { name: 'Seguir instrucción de la línea 2', exact: true })
      .click()
    await inspector.getByRole('img', { name: 'Siguiendo una aparición', exact: true }).waitFor()
    assert.equal(await page.locator('.viewrv-selected-occurrence-line:visible').count(), 1)
    assert.equal(steps(), 6)
    assert.deepEqual(errors, [])
    const closed = page.waitForEvent('close', { timeout: 18000 })
    await page.evaluate(() => window.viewrvDesktop.requestWindowClose())
    await closed
    await instance.close()
    instance = null
    console.log(
      'PC-I07 loop: two simultaneous appearances at PC=0, explicit original follow, retirement without rebinding or camera change, and explicit new appearance passed. Six literal UART captures; no CPU simulator or extra STEP.',
    )
  },
  { coreModule: 'educational_core', trace: 'loop' },
).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
