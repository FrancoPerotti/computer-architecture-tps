// Gesture input is isolated from the docking smoke test so Chromium starts with a fresh input state.
const assert = require('node:assert/strict')
const { withGui, until } = require('./gui-fixture.cjs')
const { openConnection, closeConnection, menuCommand } = require('./ui-commands.cjs')

async function checkTouchCamera(frame) {
  const result = await frame.evaluate(async () => {
    const graph = window.tp3Viewer.viewer.graph
    const canvas = graph.container
    const box = canvas.getBoundingClientRect()
    const x = box.width * 0.55
    const y = box.height * 0.45
    const camera = () => ({
      scale: graph.view.scale,
      x: (canvas.scrollLeft + x) / graph.view.scale - graph.view.translate.x,
      y: (canvas.scrollTop + y) / graph.view.scale - graph.view.translate.y,
    })
    const pointer = (type, pointerId, offsetX, offsetY = 0) =>
      canvas.dispatchEvent(
        new PointerEvent(type, {
          pointerType: 'touch',
          pointerId,
          clientX: box.left + x + offsetX,
          clientY: box.top + y + offsetY,
          bubbles: true,
          cancelable: true,
        }),
      )
    const paint = () =>
      new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    const before = camera()
    pointer('pointerdown', 1, -36)
    pointer('pointerdown', 2, 36)
    pointer('pointermove', 1, -64)
    pointer('pointermove', 2, 64)
    await paint()
    const spread = camera()
    pointer('pointermove', 1, -27)
    pointer('pointermove', 2, 27)
    await paint()
    const shrunk = camera()
    pointer('pointerup', 2, 27)
    pointer('pointermove', 1, -50, 36)
    pointer('pointerup', 1, -50, 36)
    const released = camera()
    pointer('pointerdown', 3, -42)
    pointer('pointerdown', 4, 42)
    pointer('pointercancel', 3, -42)
    pointer('pointercancel', 4, 42)
    pointer('pointerdown', 5, 0)
    pointer('pointermove', 5, -45, -30)
    pointer('pointerup', 5, -45, -30)
    const panned = camera()
    canvas.dispatchEvent(
      new WheelEvent('wheel', {
        deltaY: -120,
        ctrlKey: true,
        clientX: box.left + x,
        clientY: box.top + y,
        bubbles: true,
        cancelable: true,
      }),
    )
    await paint()
    return { before, spread, shrunk, released, panned, wheelScale: graph.view.scale }
  })
  const { before, spread, shrunk, released, panned, wheelScale } = result
  assert.ok(spread.scale > before.scale * 1.5, 'Spreading two contacts did not zoom in')
  assert.ok(shrunk.scale < before.scale, 'Pinching two contacts did not zoom out')
  assert.ok(Math.abs(spread.x - before.x) < 2 / spread.scale, 'Pinch shifted the midpoint x')
  assert.ok(Math.abs(spread.y - before.y) < 2 / spread.scale, 'Pinch shifted the midpoint y')
  assert.deepEqual(released, shrunk, 'A finger left after pinching moved the camera')
  assert.equal(panned.scale, shrunk.scale)
  assert.ok((panned.x - shrunk.x) * panned.scale > 30, 'Finger did not pan horizontally')
  assert.ok((panned.y - shrunk.y) * panned.scale > 20, 'Finger did not pan vertically')
  assert.ok(wheelScale > panned.scale, 'Ctrl+wheel did not zoom in')
}

async function checkTouchpadCamera(page, frame) {
  const box = await frame.locator('#diagram').boundingBox()
  const x = Math.round(box.x + box.width * 0.55)
  const y = Math.round(box.y + box.height * 0.45)
  const camera = () =>
    frame.evaluate(
      async ({ x, y }) => {
        await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
        const { view, container } = window.tp3Viewer.viewer.graph
        return {
          scale: view.scale,
          x: (container.scrollLeft + x) / view.scale - view.translate.x,
          y: (container.scrollTop + y) / view.scale - view.translate.y,
        }
      },
      { x: x - box.x, y: y - box.y },
    )
  const cdp = await page.context().newCDPSession(page)
  try {
    await page.mouse.move(x, y)
    const before = await camera()
    const pageScale = await page.evaluate(() => window.visualViewport.scale)
    // Chromium's mouse source goes through touchpad pinch routing across the iframe.
    const pinch = (scaleFactor) =>
      cdp.send('Input.synthesizePinchGesture', { x, y, scaleFactor, gestureSourceType: 'mouse' })
    await pinch(1.6)
    const spread = await camera()
    await pinch(0.625)
    const shrunk = await camera()
    assert.ok(spread.scale > before.scale * 1.45, 'Touchpad pinch did not zoom in')
    assert.ok(shrunk.scale < spread.scale * 0.75, 'Touchpad pinch did not zoom out')
    assert.ok(Math.abs(shrunk.scale / before.scale - 1) < 0.1, 'Inverse pinches did not cancel')
    for (const current of [spread, shrunk]) {
      assert.ok(Math.abs(current.x - before.x) * current.scale < 5, 'Pinch shifted the anchor x')
      assert.ok(Math.abs(current.y - before.y) * current.scale < 5, 'Pinch shifted the anchor y')
    }
    assert.equal(await page.evaluate(() => window.visualViewport.scale), pageScale)
  } finally {
    await cdp.detach()
  }
}

async function checkViewer(page, title) {
  const element = await page.locator(`iframe[title="${title}"]`).elementHandle()
  const frame = await element.contentFrame()
  await frame.locator('#zoom-in:enabled').waitFor()
  await frame.locator('#zoom-in').click()
  await checkTouchCamera(frame)
  await checkTouchpadCamera(page, frame)
}

;(async () => {
  await withGui('touch-exploration', async ({ page, errors }) => {
    await checkViewer(page, 'Visor interactivo del pipeline')
    assert.deepEqual(errors, [])
  })

  await withGui(
    'touch-session',
    async ({ page, errors }) => {
      await page.getByRole('button', { name: 'IDE', exact: true }).click()
      await menuCommand(page, 'Archivo', 'Abrir ejemplo…')
      await page.getByRole('button', { name: 'Sumar dos números', exact: true }).click()
      await openConnection(page)
      await page.getByRole('button', { name: 'Preparar Basys 3', exact: true }).click()
      await page.getByText(/Programación confirmada. Comunicación UART comprobada/).waitFor()
      await closeConnection(page)
      for (const name of ['Ensamblar', 'Cargar', 'Empezar debug']) {
        const control = page.getByRole('button', { name, exact: true })
        await until(() => control.isEnabled())
        await control.click()
      }
      await menuCommand(page, 'Ver', 'Abrir diagrama de depuración')
      await checkViewer(page, 'Diagrama de la sesión')
      await page.getByText('Sin captura recibida', { exact: true }).waitFor()
      assert.deepEqual(errors, [])
    },
    { coreModule: 'educational_core', trace: 'addition' },
  )
  console.log('Both viewers pan and pinch with touch and zoom with the touchpad and Ctrl+wheel.')
})().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
