import { useRef, type MouseEvent, type PointerEvent } from 'react'

interface TouchStart {
  pointer: number
  x: number
  y: number
}

interface TouchDrag extends TouchStart {
  tab: HTMLElement
  layout: HTMLElement
  transfer?: DataTransfer
}

const moved = (event: PointerEvent, start: TouchStart) =>
  Math.hypot(event.clientX - start.x, event.clientY - start.y) >= 8

function dispatch(target: HTMLElement, type: string, event: PointerEvent, data: DataTransfer) {
  return target.dispatchEvent(
    new DragEvent(type, {
      bubbles: true,
      cancelable: true,
      clientX: event.clientX,
      clientY: event.clientY,
      dataTransfer: data,
    }),
  )
}

// Feed touch drags into FlexLayout's normal drop preview and docking rules.
export function useTouchTabDrag() {
  const active = useRef<TouchDrag | null>(null)
  const closeTap = useRef<(TouchStart & { button: HTMLElement }) | null>(null)
  const suppressClick = useRef(false)

  function onPointerDown(event: PointerEvent) {
    if (event.pointerType !== 'touch' || !event.isPrimary) return
    suppressClick.current = false
    const target = event.target as Element
    const tab = target.closest<HTMLElement>('.flexlayout__tab_button[draggable="true"]')
    const layout = tab?.closest<HTMLElement>('.flexlayout__layout')
    if (!tab || !layout) return
    const start = { pointer: event.pointerId, x: event.clientX, y: event.clientY }
    const button = target.closest<HTMLElement>('.flexlayout__tab_button_trailing')
    if (button) closeTap.current = { ...start, button }
    else active.current = { ...start, tab, layout }
  }

  function onPointerMove(event: PointerEvent) {
    const close = closeTap.current
    if (close?.pointer === event.pointerId && moved(event, close)) closeTap.current = null
    const drag = active.current
    if (!drag || event.pointerId !== drag.pointer) return
    if (!drag.transfer) {
      if (!moved(event, drag)) return
      const transfer = new DataTransfer()
      if (!dispatch(drag.tab, 'dragstart', event, transfer)) {
        active.current = null
        return
      }
      drag.transfer = transfer
      suppressClick.current = true
      dispatch(drag.layout, 'dragenter', event, transfer)
    }
    event.preventDefault()
    dispatch(drag.layout, 'dragover', event, drag.transfer)
  }

  function finish(event: PointerEvent) {
    const close = closeTap.current
    if (close?.pointer === event.pointerId) {
      closeTap.current = null
      if (
        event.type === 'pointerup' &&
        !moved(event, close) &&
        close.button.contains(
          close.button.ownerDocument.elementFromPoint(event.clientX, event.clientY),
        )
      ) {
        // A touch drag can suppress Chromium's compatibility click on the next tap.
        // Activate the existing close control on release, through FlexLayout's usual action.
        event.preventDefault()
        suppressClick.current = true
        close.button.click()
      }
      return
    }
    const drag = active.current
    if (!drag || event.pointerId !== drag.pointer) return
    active.current = null
    if (!drag.transfer) return
    event.preventDefault()
    // FlexLayout cancels dragover at a legal drop target. Recheck at release.
    const { left, right, top, bottom } = drag.layout.getBoundingClientRect()
    const inside =
      event.clientX >= left &&
      event.clientX < right &&
      event.clientY >= top &&
      event.clientY < bottom
    if (
      event.type === 'pointerup' &&
      inside &&
      !dispatch(drag.layout, 'dragover', event, drag.transfer)
    )
      dispatch(drag.layout, 'drop', event, drag.transfer)
    dispatch(drag.tab, 'dragend', event, drag.transfer)
  }

  function onClickCapture(event: MouseEvent) {
    if (
      !suppressClick.current ||
      (event.nativeEvent as globalThis.PointerEvent).pointerType !== 'touch'
    )
      return
    suppressClick.current = false
    event.preventDefault()
    event.stopPropagation()
  }

  return {
    onPointerDownCapture: onPointerDown,
    onPointerMove,
    onPointerUp: finish,
    onPointerCancel: finish,
    onLostPointerCapture: finish,
    onClickCapture,
  }
}
