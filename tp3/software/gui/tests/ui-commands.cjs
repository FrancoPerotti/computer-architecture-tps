// Common real menu interactions after the PC-I06 toolbar/menu separation.
async function menuCommand(page, group, command) {
  await page.getByRole('button', { name: group, exact: true }).click()
  await page.getByRole('menuitem', { name: command, exact: true }).click()
}
async function openConnection(page) {
  await menuCommand(page, 'Ver', 'Conexión con la placa…')
  await page.getByRole('dialog', { name: 'Conexión con la placa', exact: true }).waitFor()
}
async function closeConnection(page) {
  await page
    .getByRole('dialog', { name: 'Conexión con la placa', exact: true })
    .getByRole('button', { name: 'Cerrar diálogo', exact: true })
    .click()
}
async function waitForCore(page) {
  await openConnection(page)
  await page.getByText('Conectado al core', { exact: true }).waitFor({ timeout: 25000 })
  await closeConnection(page)
}
module.exports = { menuCommand, openConnection, closeConnection, waitForCore }
