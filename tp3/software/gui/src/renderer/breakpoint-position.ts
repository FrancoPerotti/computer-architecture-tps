import { useLayoutEffect, type RefObject } from 'react'
import type * as monaco from 'monaco-editor/editor/editor.api.js'

/** Anchor to the visible arrow, including editor scroll, split resizing and UI scale. */
export function useBreakpointPosition(
  editor: monaco.editor.IStandaloneCodeEditor | null,
  line: number | null,
  popup: RefObject<HTMLDivElement | null>,
  dismiss: () => void,
) {
  useLayoutEffect(() => {
    const node = popup.current,
      root = editor?.getDomNode()
    if (!editor || !root || !node || line === null) return
    const parent = node.offsetParent as HTMLElement | null
    if (!parent) return
    let frame = 0
    const position = () => {
      const visible = editor.getScrolledVisiblePosition({ lineNumber: line, column: 1 })
      const layout = editor.getLayoutInfo()
      if (!visible || visible.top < 0 || visible.top + visible.height > layout.height) {
        dismiss()
        return
      }
      const bounds = parent.getBoundingClientRect()
      const scaleX = bounds.width / parent.offsetWidth || 1
      const scaleY = bounds.height / parent.offsetHeight || 1
      const editorBounds = root.getBoundingClientRect()
      // Use the same public coordinates as the arrow overlay. Its React commit may
      // follow this frame; measuring that DOM node while scrolling would lag a frame.
      const left =
        (editorBounds.left +
          (layout.glyphMarginLeft + layout.glyphMarginWidth - visible.height) * scaleX -
          bounds.left) /
        scaleX
      const top = (editorBounds.top + (visible.top + visible.height) * scaleY - bounds.top) / scaleY
      node.style.maxWidth = `${Math.max(0, parent.clientWidth - 16)}px`
      node.style.minWidth = `${Math.min(230, Math.max(0, parent.clientWidth - 16))}px`
      node.style.left = `${Math.max(8, Math.min(left, parent.clientWidth - node.offsetWidth - 8))}px`
      const below = parent.clientHeight - top - 8
      const above = top - visible.height - 8
      const flip = below < Math.min(node.scrollHeight, 150) && above > below
      node.style.maxHeight = `${Math.max(0, flip ? above : below)}px`
      node.style.top = `${flip ? top - visible.height - node.offsetHeight - 4 : top + 4}px`
    }
    const schedule = () => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(position)
    }
    const subscriptions = [
      editor.onDidScrollChange(schedule),
      editor.onDidLayoutChange(schedule),
      editor.onDidChangeConfiguration(schedule),
    ]
    const resize = new ResizeObserver(schedule)
    resize.observe(parent)
    window.addEventListener('resize', schedule)
    position()
    return () => {
      cancelAnimationFrame(frame)
      resize.disconnect()
      window.removeEventListener('resize', schedule)
      for (const subscription of subscriptions) subscription.dispose()
    }
  }, [editor, line, popup, dismiss])
}
