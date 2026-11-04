export interface Instruction {
  mnemonic: string
  description: string
  syntax: string
  operands: { name: string; description: string }[]
  example: string
  notes: string[]
}

// Both educational surfaces read the same local instruction contract.
export function instructionDocumentation(item: Instruction): string {
  return [
    '**Sintaxis**',
    '`' + item.syntax + '`',
    '',
    item.description,
    '',
    '**Parámetros**',
    item.operands.length
      ? item.operands
          .map((operand) => '- `' + operand.name + '`: ' + operand.description)
          .join('\n')
      : 'No recibe operandos.',
    '',
    '**Ejemplo**',
    '```viewrv-assembly\n' + item.example + '\n```',
    ...item.notes.flatMap((note) => ['', note]),
  ].join('\n')
}
