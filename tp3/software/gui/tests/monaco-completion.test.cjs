const { test } = require('node:test')
const assert = require('node:assert/strict')
const { pinCompletionDetails } = require('../.test-build/renderer/monaco-completion')
function fixture() {
  const listeners = new Map()
  const event = (name) => (listener) => {
    listeners.set(name, listener)
    return { dispose: () => listeners.delete(name) }
  }
  let visible = false,
    calls = 0
  const widget = {
    onDidShow: event('show'),
    onDidHide: event('hide'),
    onDidFocus: event('focus'),
    _isDetailsVisible: () => visible,
  }
  const editor = {
    getContribution: () => ({ widget: { value: widget } }),
    addAction(action) {
      assert.equal(action.precondition, 'suggestWidgetVisible && suggestWidgetHasFocusedSuggestion')
      return event('key')(action.run)
    },
    trigger(_source, action) {
      assert.equal(action, 'toggleSuggestionDetails')
      visible = !visible
      calls++
    },
  }
  return {
    editor,
    widget,
    listeners,
    emit: (name) => listeners.get(name)?.(),
    hideDetails: () => {
      visible = false
    },
    get visible() {
      return visible
    },
    get calls() {
      return calls
    },
  }
}
test('completion adapter expands native details without replacing widget methods', () => {
  const f = fixture(),
    before = { ...f.widget },
    subscription = pinCompletionDetails(f.editor, [1])
  f.emit('focus')
  assert.equal(f.visible, true)
  assert.equal(f.calls, 1)
  f.hideDetails()
  f.emit('key')
  assert.equal(f.visible, true, 'Details must stay open before delayed onDidShow')
  f.emit('show')
  f.emit('focus')
  assert.equal(f.calls, 2)
  f.hideDetails()
  f.emit('key')
  assert.equal(f.visible, true)
  f.emit('hide')
  f.hideDetails()
  f.emit('key')
  assert.equal(f.visible, false)
  assert.deepEqual(f.widget, before)
  subscription.dispose()
  subscription.dispose()
  assert.equal(f.listeners.size, 0)
})
test('completion adapter keeps native completion intact for an incompatible surface', () => {
  for (const contribution of [null, {}, { widget: { value: {} } }]) {
    const subscription = pinCompletionDetails(
      {
        getContribution: () => contribution,
        addAction() {
          assert.fail('Unsupported widget must not install handlers')
        },
        trigger() {
          assert.fail('Unsupported widget must not run commands')
        },
      },
      [1],
    )
    subscription.dispose()
  }
})
