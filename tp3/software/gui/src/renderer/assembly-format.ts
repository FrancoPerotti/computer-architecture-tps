type FormattingOptions = { insertSpaces: boolean; tabSize: number }
type InstructionSyntax = { mnemonic: string; syntax: string }

/** Whitespace only: retain line identities, token spelling and comment contents. */
export function createAssemblyLineFormatter(instructions: readonly InstructionSyntax[]) {
  const syntax = new Map(instructions.map((item) => [item.mnemonic, item.syntax]))
  return (line: string, options: FormattingOptions): string => {
    const bom = line.startsWith('\uFEFF') ? '\uFEFF' : ''
    const text = line.slice(bom.length)
    const commentAt = text.indexOf('#')
    const comment = commentAt < 0 ? '' : text.slice(commentAt)
    const code = (commentAt < 0 ? text : text.slice(0, commentAt)).replace(/^[ \t]+|[ \t]+$/g, '')
    if (!code) return comment ? line : bom
    // Leave unsupported constructs untouched, including quotes and non-ASCII separators.
    if (/[^\x20-\x7e\t]|["';]/.test(code)) return line
    const label = /^([A-Za-z_][A-Za-z0-9_]*)[ \t]*:[ \t]*/.exec(code)
    const rest = label ? code.slice(label[0].length) : code
    let formatted: string
    if (!rest && label) formatted = `${label[1]}:`
    else {
      const instruction = /^([a-z][a-z0-9]*)(?:[ \t]+(.*))?$/.exec(rest)
      if (!instruction || !syntax.has(instruction[1])) return line
      const mnemonic = instruction[1]
      const operands = instruction[2]?.split(',').map((operand) => operand.trim())
      // Only remove parentheses spacing where the assembler accepts a memory operand.
      // Never merge a split register, sign, literal or identifier into a valid token.
      if (operands?.length === 2 && syntax.get(mnemonic)!.includes('('))
        operands[1] = operands[1].replace(/^([^\s()]+)[ \t]*\([ \t]*([^\s()]+)[ \t]*\)$/, '$1($2)')
      const indent = options.insertSpaces ? ' '.repeat(options.tabSize) : '\t'
      formatted = `${label ? `${label[1]}: ` : indent}${mnemonic}${operands ? ` ${operands.join(', ')}` : ''}`
    }
    return bom + formatted.trimEnd() + (comment ? `  ${comment}` : '')
  }
}
