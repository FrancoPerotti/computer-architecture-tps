/** Transient presentation only. Every caller owns and cancels its animation. */
export function feedbackAnimation(
  element: HTMLElement,
  frames: Keyframe[],
  options: KeyframeAnimationOptions,
  finish: () => void = () => {},
): () => void {
  const preference = window.matchMedia('(prefers-reduced-motion: reduce)')
  if (preference.matches) {
    finish()
    return () => {}
  }
  const animation = element.animate(frames, options)
  let finished = false
  const dispose = () => {
    if (finished) return
    finished = true
    preference.removeEventListener('change', reduce)
    animation.cancel()
    finish()
  }
  const reduce = () => {
    if (preference.matches) dispose()
  }
  animation.onfinish = dispose
  preference.addEventListener('change', reduce)
  return dispose
}
