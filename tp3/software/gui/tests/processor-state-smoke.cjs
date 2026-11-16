// TEST-PC-004/006/007/019: received values, educational reference and retained terminal state.
const assert = require('node:assert/strict')
const { readFileSync, writeFileSync } = require('node:fs')
const { resolve } = require('node:path')
const { withGui, until } = require('./gui-fixture.cjs')
const { menuCommand, openConnection, closeConnection } = require('./ui-commands.cjs')

async function start(page) {
  await openConnection(page)
  await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
  await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
  await closeConnection(page)
  await until(() => page.getByRole('button', { name: 'Ensamblar', exact: true }).isEnabled())
  await page.getByRole('button', { name: 'Ensamblar', exact: true }).click()
  await until(() => page.getByRole('button', { name: 'Cargar', exact: true }).isEnabled())
  await page.getByRole('button', { name: 'Cargar', exact: true }).click()
  await until(() => page.getByRole('button', { name: 'Empezar debug', exact: true }).isEnabled())
  await page.getByRole('button', { name: 'Empezar debug', exact: true }).click()
}
const countSteps = (root) =>
  readFileSync(resolve(root, 'uart.tx'), 'utf8')
    .split('\n')
    .filter((line) => line === '03').length
async function step(page, results, cycle) {
  await until(() => page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).isEnabled())
  await page.getByRole('button', { name: 'Avanzar un ciclo', exact: true }).click()
  await results.getByRole('group', { name: `Ciclo observado: ${cycle}`, exact: true }).waitFor()
}

;(async () => {
  await withGui(
    'processor-state',
    async ({ page, core, root, gui, errors }) => {
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
      await page
        .getByRole('dialog', { name: 'Abrir ejemplo', exact: true })
        .getByRole('button', { name: 'Sumar dos números', exact: true })
        .click()
      await start(page)
      const results = page.getByRole('region', { name: 'Estado del procesador', exact: true })
      const global = results.getByRole('region', { name: 'Estado global recibido', exact: true })
      await results
        .getByRole('heading', { name: 'Listo para el primer ciclo', exact: true })
        .waitFor()
      assert.equal(await global.count(), 0, 'Opening debug fabricated a capture')
      assert.equal(countSteps(root), 0)
      for (let cycle = 1; cycle <= 4; cycle++) await step(page, results, cycle)
      assert.equal(countSteps(root), 4)
      await global.getByLabel('Formato de pc', { exact: true }).waitFor()
      const formatState = global.getByLabel('Formato de global_state', { exact: true })
      const shownValue = (name) =>
        global
          .getByLabel(`Formato de ${name}`, { exact: true })
          .evaluate((node) => node.parentElement.querySelector('code').textContent)
      assert.equal(await shownValue('global_state'), 'STEPPING (0x05)')
      assert.equal(await shownValue('cycle_count'), '4')
      await formatState.selectOption('binary')
      assert.equal(await shownValue('global_state'), '0b00000101')
      await formatState.selectOption('hex')
      assert.equal(await shownValue('global_state'), '0x05')
      await formatState.selectOption('state-name')
      for (const latch of ['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB']) {
        await results
          .getByRole('region', { name: `Registro ${latch}`, exact: true })
          .getByRole('img', { name: 'Instrucción válida', exact: true })
          .waitFor()
      }
      const guide = results.getByLabel('Referencia educativa del ejemplo', { exact: true })
      const expected = guide.getByRole('region', { name: 'Guía del ciclo observado', exact: true })
      const received = guide.getByRole('region', {
        name: 'Captura recibida del ejemplo',
        exact: true,
      })
      assert.deepEqual(
        await expected.locator('tbody tr').first().getByRole('cell').allTextContents(),
        ['0x0000000c', 'aparición 4'],
      )
      assert.deepEqual(
        await received.locator('tbody tr').first().getByRole('cell').allTextContents(),
        ['Válido', '0x0000000c'],
      )
      for (const stage of ['IF', 'ID', 'EX', 'MEM', 'WB'])
        await results.getByRole('region', { name: 'Etapa ' + stage, exact: true }).waitFor()
      await results
        .getByRole('region', { name: 'Etapa WB', exact: true })
        .getByText('Sin instrucción activa', { exact: true })
        .waitFor()
      const bank = results.getByText('Banco de registros arquitectónicos · x0–x31', { exact: true })
      await results.getByLabel('Formato de x31', { exact: true }).waitFor()
      const memory = results.getByLabel('Memoria observada', { exact: true })
      await memory.getByRole('heading', { name: 'Sin datos de memoria', exact: true }).waitFor()
      await memory.locator('summary').click()
      await page.emulateMedia({ reducedMotion: 'reduce' })
      await step(page, results, 5)
      const ifid = results.getByRole('region', { name: 'Registro IF/ID', exact: true })
      await ifid.getByRole('img', { name: 'Candidato de fallo de fetch', exact: true }).waitFor()
      await ifid
        .getByText('Fetch pendiente de confirmación · PC 0x00000010 · INSTRUCTION_ACCESS_FAULT', {
          exact: true,
        })
        .waitFor()
      assert.equal(await results.getByRole('alert').count(), 0)
      await ifid.getByRole('heading').evaluate((node) => node.scrollIntoView({ block: 'center' }))
      await page.screenshot({ path: resolve(gui, '../build/gui-halt-5-fetch-pending.png') })
      assert.ok(
        await results.getByLabel('Formato de x31', { exact: true }).isVisible(),
        'Capture update collapsed the register bank',
      )
      await step(page, results, 6)
      assert.equal(await shownValue('global_state'), 'HALT_DRAIN_STEP (0x07)')
      assert.equal(await shownValue('cycle_count'), '6')
      await ifid.getByRole('img', { name: 'Sin instrucción activa', exact: true }).waitFor()
      await results.getByText('HALT recibido: drenando el pipeline.', { exact: true }).waitFor()
      assert.equal(await results.getByRole('alert').count(), 0)
      await results
        .getByText('HALT recibido: drenando el pipeline.', { exact: true })
        .evaluate((node) => node.scrollIntoView({ block: 'center' }))
      await page.screenshot({ path: resolve(gui, '../build/gui-halt-6-drain.png') })
      assert.equal(await memory.evaluate((node) => node.open), false, 'Capture reopened memory')
      await bank.click()
      await results.getByLabel('Formato de x31', { exact: true }).waitFor({ state: 'hidden' })
      assert.equal(countSteps(root), 6, 'Inspection emitted STEP')
      await step(page, results, 7)
      const finished = results.getByRole('heading', { name: 'Ejecución finalizada', exact: true })
      await finished.waitFor()
      assert.equal(await results.getByRole('alert').count(), 0)
      await finished.evaluate((node) => node.scrollIntoView({ block: 'center' }))
      await page.screenshot({ path: resolve(gui, '../build/gui-halt-7-finished.png') })
      assert.equal(countSteps(root), 7)
      await page.getByRole('button', { name: 'Detener depuración', exact: true }).click()
      await page
        .getByRole('tab', { name: 'Estado del procesador', exact: true })
        .getByTitle('Cerrar tab')
        .click()
      await menuCommand(page, 'Ver', 'Abrir vista de depuración')
      await results.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
      core.kill('SIGKILL')
      await results.getByText('Se perdió la conexión con el core', { exact: true }).waitFor()
      await global.getByLabel('Formato de pc', { exact: true }).waitFor()
      assert.equal(countSteps(root), 7)
      assert.deepEqual(errors, [])
    },
    { coreModule: 'educational_core', trace: 'addition' },
  )

  await withGui(
    'processor-fetch-fault',
    async ({ page, instance, root, gui, errors }) => {
      const source = resolve(root, 'fetch-fault.s')
      writeFileSync(source, 'addi x1,x0,5\n')
      await instance.evaluate(({ dialog }, path) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [path] })
      }, source)
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir programa…')
      await start(page)
      const diagram = page.getByRole('region', { name: 'Diagrama de la sesión', exact: true })
      const results = page.getByRole('region', { name: 'Estado del procesador', exact: true })
      const openDiagram = results.getByRole('button', {
        name: 'Abrir diagrama de depuración',
        exact: true,
      })
      const candidate = { name: 'Candidato de fallo de fetch', exact: true }
      for (const [cycle, phase] of [
        [1, 'initial'],
        [2, 'pending'],
        [3, 'drain'],
        [4, 'drain'],
        [5, 'terminal'],
      ]) {
        await page.getByRole('tab', { name: 'Estado del procesador', exact: true }).click()
        await step(page, results, cycle)
        await openDiagram.click()
        await diagram.getByText(`Ciclo observado · ${cycle}`, { exact: true }).waitFor()
        assert.equal(await page.getByRole('tab', { name: 'Pipeline', exact: true }).count(), 1)
        assert.equal(countSteps(root), cycle, 'Opening the diagram issued STEP')
        if (cycle === 1)
          await page
            .frameLocator('iframe[title="Diagrama de la sesión"]')
            .locator('#zoom-in:enabled')
            .waitFor()
        for (const [tab, view] of [
          ['Pipeline', diagram],
          ['Estado del procesador', results],
        ]) {
          await page.getByRole('tab', { name: tab, exact: true }).click()
          if (phase === 'pending') {
            await view.getByRole('img', candidate).waitFor()
            await view
              .getByText(
                'Fetch pendiente de confirmación · PC 0x00000004 · INSTRUCTION_ACCESS_FAULT',
                { exact: true },
              )
              .waitFor()
          } else {
            assert.equal(await view.getByRole('img', candidate).count(), 0)
          }
          const alert = view.getByRole('alert')
          if (phase === 'initial' || phase === 'pending') {
            assert.equal(await alert.count(), 0)
          } else {
            await alert
              .getByText(
                phase === 'drain' ? 'Fallo confirmado · drenando el pipeline' : 'Fallo confirmado',
                { exact: true },
              )
              .waitFor()
            await alert
              .getByText('Causa: INSTRUCTION_ACCESS_FAULT · PC del fault: 0x00000004', {
                exact: true,
              })
              .waitFor()
          }
        }
        if (cycle >= 2) {
          await page.getByRole('tab', { name: 'Pipeline', exact: true }).click()
          await page.screenshot({ path: resolve(gui, `../build/gui-fetch-${cycle}-${phase}.png`) })
        }
      }
      assert.equal(countSteps(root), 5)
      assert.deepEqual(errors, [])
    },
    { coreModule: 'educational_core', trace: 'fetch-fault' },
  )

  await withGui(
    'processor-memory',
    async ({ page, instance, root, errors }) => {
      const source = resolve(root, 'memory.s')
      writeFileSync(source, 'sw x0,0(x0)\nsb x0,7(x0)\nlw x1,0(x0)\nhalt\n')
      await instance.evaluate(({ dialog }, path) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [path] })
      }, source)
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir programa…')
      await start(page)
      const results = page.getByRole('region', { name: 'Estado del procesador', exact: true })
      for (let cycle = 1; cycle <= 5; cycle++) await step(page, results, cycle)
      const filter = results.getByLabel('Filtrar dirección de memoria', { exact: true })
      await filter.fill('0x7')
      await results.getByLabel('Formato de mem[0x7]', { exact: true }).waitFor()
      assert.equal(await results.getByLabel('Formato de mem[0x0]', { exact: true }).count(), 0)
      await filter.fill('0xff')
      await results.getByRole('heading', { name: 'Sin coincidencias', exact: true }).waitFor()
      await results.getByRole('button', { name: 'Limpiar filtro de memoria', exact: true }).click()
      await results.getByLabel('Formato de mem[0x0]', { exact: true }).waitFor()
      await results.getByLabel('Formato de mem[0x7]', { exact: true }).waitFor()
      assert.equal(countSteps(root), 5, 'Memory filtering emitted STEP')
      assert.deepEqual(errors, [])
    },
    { coreModule: 'educational_core', trace: 'memory' },
  )
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
