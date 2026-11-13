interface IDisposable {
  dispose(): void
}
interface CompletionEditor {
  getContribution(id: string): unknown
  trigger(source: string, action: string, payload: unknown): void
  addAction(action: {
    id: string
    label: string
    keybindings: number[]
    precondition: string
    run(): void
  }): IDisposable
}

interface DetailsWidget {
  onDidShow(listener: () => void): IDisposable
  onDidHide(listener: () => void): IDisposable
  onDidFocus(listener: () => void): IDisposable
  _isDetailsVisible(): boolean
}

function detailsWidget(value: unknown): value is DetailsWidget {
  return (
    value !== null &&
    typeof value === 'object' &&
    ['onDidShow', 'onDidHide', 'onDidFocus', '_isDetailsVisible'].every(
      (key) => typeof (value as Record<string, unknown>)[key] === 'function',
    )
  )
}

/** Compatibility boundary for Monaco 0.57.0, pinned in package.json.
 * Monaco exposes no public suggestion-focus event. Read only the guarded event
 * surface here; never replace its methods. A changed surface keeps native
 * completion working. The actual pinned widget is covered by completion-smoke.
 */
export function pinCompletionDetails(
  instance: CompletionEditor,
  keybindings: number[],
): IDisposable {
  const contribution = instance.getContribution('editor.contrib.suggestController')
  const container =
    contribution !== null && typeof contribution === 'object' && 'widget' in contribution
      ? contribution.widget
      : null
  const widget =
    container !== null && typeof container === 'object' && 'value' in container
      ? container.value
      : null
  if (!detailsWidget(widget)) return { dispose() {} }

  let shown = false
  let disposed = false
  const expand = () => {
    if (!disposed && !widget._isDetailsVisible())
      instance.trigger('viewrv', 'toggleSuggestionDetails', null)
  }
  const subscriptions = [
    widget.onDidShow(() => {
      shown = true
      expand()
    }),
    widget.onDidHide(() => {
      shown = false
    }),
    widget.onDidFocus(() => {
      // Monaco emits item focus before its delayed onDidShow notification.
      shown = true
      expand()
    }),
    // A public editor action takes precedence only while a suggestion is focused.
    // This prevents a hide/show frame without replacing Monaco's command or methods.
    instance.addAction({
      id: 'viewrv.completion.keepDetails',
      label: 'Mostrar descripción de la instrucción',
      keybindings,
      precondition: 'suggestWidgetVisible && suggestWidgetHasFocusedSuggestion',
      run() {
        if (shown) expand()
      },
    }),
  ]
  return {
    dispose() {
      if (disposed) return
      disposed = true
      subscriptions.forEach((item) => item.dispose())
    },
  }
}
