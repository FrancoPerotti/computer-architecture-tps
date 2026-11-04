const assert = require('node:assert/strict')
const { resolve } = require('node:path')
const { withGui, until } = require('./gui-fixture.cjs')
const { menuCommand } = require('./ui-commands.cjs')

withGui('instruction-resource', async ({ page, errors, gui }) => {
  // The language is already initialized. Fail only the catalog's own request.
  // Electron's custom protocol does not pass through Playwright's HTTP routing.
  // Inject transport failures in this isolated renderer, leaving the real loader intact.
  await page.evaluate(() => {
    const nativeFetch = window.fetch.bind(window)
    window.__catalogFault = 'http'
    window.__catalogFaultSeen = []
    window.fetch = (url, init) => {
      if (!String(url).endsWith('/instructions.json') || !window.__catalogFault)
        return nativeFetch(url, init)
      const fault = window.__catalogFault
      window.__catalogFaultSeen.push(fault)
      if (fault === 'network') return Promise.reject(new TypeError('Failed to fetch'))
      const body = fault === 'json' ? '{' : fault === 'schema' ? '[{"mnemonic":"add"}]' : '{}'
      return Promise.resolve(
        new Response(body, {
          status: fault === 'http' ? 503 : 200,
          headers: { 'Content-Type': 'application/json' },
        }),
      )
    }
  })
  await menuCommand(page, 'Ayuda', 'Catálogo de instrucciones')
  const catalog = page.getByRole('region', { name: 'Catálogo de instrucciones', exact: true })
  for (const kind of ['http', 'json', 'schema', 'network']) {
    await page.evaluate((kind) => {
      window.__catalogFault = kind
    }, kind)
    if (kind !== 'http')
      await catalog
        .getByRole('button', { name: 'Reintentar carga del catálogo', exact: true })
        .click()
    await until(() => page.evaluate((kind) => window.__catalogFaultSeen.at(-1) === kind, kind))
    await catalog
      .getByRole('alert')
      .getByText('No se pudo cargar el catálogo de instrucciones. Reintentá la carga.', {
        exact: true,
      })
      .waitFor()
    assert.equal(
      await catalog.getByRole('article').count(),
      0,
      'Failure published an invalid or misleading empty catalog',
    )
  }
  await page.screenshot({ path: resolve(gui, '../build/stabilization-catalog-error.png') })
  assert.deepEqual(await page.evaluate(() => window.__catalogFaultSeen), [
    'http',
    'json',
    'schema',
    'network',
  ])
  await page.evaluate(() => {
    window.__catalogFault = null
  })
  await catalog.getByRole('button', { name: 'Reintentar carga del catálogo', exact: true }).click()
  await catalog.getByText('33 de 33 instrucciones', { exact: true }).waitFor()
  assert.equal(await catalog.getByRole('article').count(), 33)
  await catalog.getByLabel('Buscar instrucción', { exact: true }).fill('lui')
  await catalog
    .getByRole('article', { name: 'lui', exact: true })
    .getByText('lui rd, imm20', { exact: true })
    .waitFor()
  assert.deepEqual(errors, [])
  console.log(
    'Catalog HTTP, malformed JSON, invalid schema and network failures show an accessible retry; recovery restores all 33 entries and search without unhandled errors.',
  )
}).catch((error) => {
  console.error(error)
  process.exitCode = 1
})
