import 'monaco-editor/nls/lang/es.js'
import { loader } from '@monaco-editor/react'
import * as monaco from 'monaco-editor/editor/editor.api.js'
import 'monaco-editor/editor/contrib/find/browser/findController.js'
import 'monaco-editor/editor/contrib/suggest/browser/suggestController.js'
import 'monaco-editor/editor/contrib/hover/browser/hoverContribution.js'
import 'monaco-editor/editor/contrib/format/browser/formatActions.js'
import EditorWorker from 'monaco-editor/editor/editor.worker.js?worker'
import { instructionDocumentation } from './instructions'
import { readInstructions } from './instruction-resource'
import { createAssemblyLineFormatter } from './assembly-format'

self.MonacoEnvironment = { getWorker: () => new EditorWorker() }
loader.config({ monaco })
let configured = false

export async function configureEditor(): Promise<void> {
  if (configured) return
  const instructions = await readInstructions()
  monaco.languages.register({ id: 'viewrv-assembly' })
  const formatLine = createAssemblyLineFormatter(instructions)
  const mnemonics = new Set(instructions.map((item) => item.mnemonic))
  function formatLines(
    model: monaco.editor.ITextModel,
    options: monaco.languages.FormattingOptions,
    first: number,
    last: number,
  ): monaco.languages.TextEdit[] {
    const edits: monaco.languages.TextEdit[] = []
    for (let number = first; number <= last; number++) {
      const line = model.getLineContent(number),
        text = formatLine(line, options)
      if (text !== line)
        edits.push({ range: new monaco.Range(number, 1, number, line.length + 1), text })
    }
    return edits
  }
  monaco.languages.registerDocumentFormattingEditProvider('viewrv-assembly', {
    provideDocumentFormattingEdits(model, options) {
      return formatLines(model, options, 1, model.getLineCount())
    },
  })
  monaco.languages.registerDocumentRangeFormattingEditProvider('viewrv-assembly', {
    provideDocumentRangeFormattingEdits(model, range, options) {
      const last =
        range.endColumn === 1 && range.endLineNumber > range.startLineNumber
          ? range.endLineNumber - 1
          : range.endLineNumber
      return formatLines(model, options, range.startLineNumber, last)
    },
  })
  monaco.languages.registerOnTypeFormattingEditProvider('viewrv-assembly', {
    autoFormatTriggerCharacters: ['\n'],
    provideOnTypeFormattingEdits(model, position, _character, options) {
      if (position.lineNumber === 1) return []
      const previous = position.lineNumber - 1
      const edits = formatLines(model, options, previous, previous)
      const current = model.getLineContent(position.lineNumber)
      const before = model.getLineContent(previous).trim()
      const label = /^[A-Za-z_][A-Za-z0-9_]*[ \t]*:[ \t]*/.exec(before)
      const body = label ? before.slice(label[0].length) : before
      const mnemonic = /^[a-z][a-z0-9]*/.exec(body)?.[0]
      // Format the completed line and indent the new blank line, never unfinished operands.
      if ((mnemonics.has(mnemonic ?? '') || (label && !body)) && /^[ \t]*$/.test(current)) {
        const indent = options.insertSpaces ? ' '.repeat(options.tabSize) : '\t'
        if (current !== indent)
          edits.push({
            range: new monaco.Range(
              position.lineNumber,
              1,
              position.lineNumber,
              current.length + 1,
            ),
            text: indent,
          })
      }
      return edits
    },
  })
  // Also keep Alt+Shift+F available on Linux, whose Monaco default is Ctrl+Shift+I.
  monaco.editor.addKeybindingRule({
    keybinding: monaco.KeyMod.Alt | monaco.KeyMod.Shift | monaco.KeyCode.KeyF,
    command: 'editor.action.formatDocument',
    when: 'editorTextFocus && !editorReadonly && editorHasDocumentFormattingProvider',
  })
  monaco.languages.setLanguageConfiguration('viewrv-assembly', {
    comments: { lineComment: '#' },
    brackets: [['(', ')']],
  })
  monaco.languages.setMonarchTokensProvider('viewrv-assembly', {
    keywords: instructions.map((item) => item.mnemonic),
    tokenizer: {
      root: [
        [/#.*$/, 'comment'],
        [/\b(?:x[0-9]+|zero|ra|sp|gp|tp|t[0-6]|s[0-9]+|a[0-7]|fp)\b/, 'variable'],
        [/\b(?:0x[0-9a-fA-F]+|-?\d+)\b/, 'number'],
        [/[a-z][a-z0-9_]*/, { cases: { '@keywords': 'keyword', '@default': 'identifier' } }],
      ],
    },
  })
  configured = true
  const registers = [
    ...Array.from({ length: 32 }, (_, index) => `x${index}`),
    'zero',
    'ra',
    'sp',
    'gp',
    'tp',
    'fp',
    ...Array.from({ length: 7 }, (_, index) => `t${index}`),
    ...Array.from({ length: 12 }, (_, index) => `s${index}`),
    ...Array.from({ length: 8 }, (_, index) => `a${index}`),
  ]
  monaco.languages.registerCompletionItemProvider('viewrv-assembly', {
    provideCompletionItems(model, position) {
      if (
        model
          .getLineContent(position.lineNumber)
          .slice(0, position.column - 1)
          .includes('#')
      )
        return { suggestions: [] }
      const word = model.getWordUntilPosition(position)
      const range = new monaco.Range(
        position.lineNumber,
        word.startColumn,
        position.lineNumber,
        word.endColumn,
      )
      return {
        suggestions: [
          ...instructions.map((item) => ({
            label: item.mnemonic,
            kind: monaco.languages.CompletionItemKind.Keyword,
            insertText: item.mnemonic,
            documentation: { value: instructionDocumentation(item) },
            range,
          })),
          ...registers.map((register) => ({
            label: register,
            kind: monaco.languages.CompletionItemKind.Variable,
            insertText: register,
            range,
          })),
        ],
      }
    },
  })
}
