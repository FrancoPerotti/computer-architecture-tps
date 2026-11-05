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
    async ({ page, core, root, errors }) => {
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
      for (const latch of ['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB']) {
        await results
          .getByRole('region', { name: `Registro ${latch}`, exact: true })
          .getByRole('img', { name: 'Instrucción válida', exact: true })
          .waitFor()
      }
      await results.getByText('Guía educativa del ejemplo', { exact: true }).click()
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
      await results.getByText('Actividad inferida del ciclo', { exact: true }).click()
      for (const stage of ['IF', 'ID', 'EX', 'MEM', 'WB'])
        await results.getByRole('region', { name: 'Etapa ' + stage, exact: true }).waitFor()
      await results
        .getByRole('region', { name: 'Etapa WB', exact: true })
        .getByText('Sin instrucción activa', { exact: true })
        .waitFor()
      const bank = results.getByText('Banco de registros arquitectónicos · x0–x31', { exact: true })
      await bank.click()
      await results.getByLabel('Formato de x31', { exact: true }).waitFor()
      await page.emulateMedia({ reducedMotion: 'reduce' })
      await step(page, results, 5)
      await results
        .getByRole('region', { name: 'Registro IF/ID', exact: true })
        .getByRole('img', { name: 'Fallo de fetch', exact: true })
        .waitFor()
      assert.ok(
        await results.getByLabel('Formato de x31', { exact: true }).isVisible(),
        'Capture update collapsed the register bank',
      )
      await step(page, results, 6)
      await results
        .getByRole('region', { name: 'Registro IF/ID', exact: true })
        .getByRole('img', { name: 'Sin instrucción activa', exact: true })
        .waitFor()
      await results
        .getByLabel('Memoria observada', { exact: true })
        .locator(':scope > summary')
        .click()
      await results.getByRole('heading', { name: 'Sin datos de memoria', exact: true }).waitFor()
      assert.equal(countSteps(root), 6, 'Inspection emitted STEP')
      await page.getByRole('button', { name: 'Continuar', exact: true }).click()
      await results.getByRole('heading', { name: 'Ejecución finalizada', exact: true }).waitFor()
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
      await results
        .getByLabel('Memoria observada', { exact: true })
        .locator(':scope > summary')
        .click()
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
