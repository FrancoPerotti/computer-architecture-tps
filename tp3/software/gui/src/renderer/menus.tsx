import { Menu } from '@base-ui/react/menu'
import {
  BookOpen,
  Copy,
  FilePlus,
  FolderOpen,
  Save,
  Columns2,
  Rows2,
  Bug,
  Cpu,
  X,
  Undo,
  Redo,
  Scissors,
  Clipboard,
  Search,
  List,
  AlignLeft,
} from 'lucide-react'
import { useRef, type ComponentType } from 'react'
import { useCore } from './core-client'
import { documents, useDocuments } from './documents'
import { useWorkspace } from './ide-state'
export type MenuCommand =
  | 'new'
  | 'open'
  | 'example'
  | 'save'
  | 'save-as'
  | 'close'
  | 'undo'
  | 'redo'
  | 'cut'
  | 'copy'
  | 'paste'
  | 'select-all'
  | 'find'
  | 'format'
  | 'split-right'
  | 'split-bottom'
  | 'debug'
  | 'diagram'
  | 'catalog'
  | 'assembly'
  | 'connection'
  | 'recovery'
import * as styles from './theme.css'
export function sendMenu(command: MenuCommand): void {
  window.dispatchEvent(new CustomEvent('viewrv:menu', { detail: command }))
}
type Item = [MenuCommand, string, ComponentType<{ size?: number }>, boolean?]
function AppMenu({ title, items, closing }: { title: string; items: Item[]; closing: boolean }) {
  const invoked = useRef(false)
  return (
    <Menu.Root
      onOpenChange={(open) => {
        if (open) invoked.current = false
      }}
    >
      <Menu.Trigger className={styles.menuTrigger}>{title}</Menu.Trigger>
      <Menu.Portal>
        <Menu.Positioner side="bottom" align="start" sideOffset={4}>
          <Menu.Popup className={styles.menuPopup} finalFocus={() => !invoked.current}>
            {items.map(([command, label, Icon, disabled]) => (
              <Menu.Item
                key={command}
                className={styles.menuItem}
                disabled={closing || !!disabled}
                onClick={() => {
                  invoked.current = true
                  sendMenu(command)
                }}
              >
                <Icon size={15} />
                {label}
              </Menu.Item>
            ))}
          </Menu.Popup>
        </Menu.Positioner>
      </Menu.Portal>
    </Menu.Root>
  )
}
export function MenuBar() {
  useDocuments((state) => state.revision)
  const focus = useWorkspace((state) => state.focus)
  const section = useWorkspace((state) => state.section)
  const closing = useCore((state) => state.closing)
  const program = section === 'editor' && focus ? documents.get(focus)?.snapshot() : null
  const readonly = !program || program.closing || program.program.edit_protected
  const groups: [string, Item[]][] = [
    [
      'Archivo',
      [
        ['new', 'Crear programa', FilePlus],
        ['open', 'Abrir programa…', FolderOpen],
        ['example', 'Abrir ejemplo…', BookOpen],
        ['save', 'Guardar', Save, !program],
        ['save-as', 'Guardar como…', Save, !program],
        ['close', 'Cerrar tab', X],
      ],
    ],
    [
      'Editar',
      [
        ['undo', 'Deshacer', Undo, readonly],
        ['redo', 'Rehacer', Redo, readonly],
        ['cut', 'Cortar', Scissors, readonly],
        ['copy', 'Copiar', Copy, !program],
        ['paste', 'Pegar', Clipboard, readonly],
        ['select-all', 'Seleccionar todo', List, !program],
        ['find', 'Buscar', Search, !program],
        ['format', 'Formatear documento', AlignLeft, readonly],
      ],
    ],
    [
      'Ver',
      [
        ['recovery', 'Borradores recuperables…', FolderOpen],
        ['connection', 'Conexión con la placa…', Cpu],
        ['split-right', 'Dividir izquierda/derecha', Columns2],
        ['split-bottom', 'Dividir arriba/abajo', Rows2],
        ['debug', 'Abrir vista de depuración', Bug],
        ['diagram', 'Abrir diagrama de depuración', Cpu],
        ['assembly', 'Vista ensamblada', List, !program],
      ],
    ],
    ['Ayuda', [['catalog', 'Catálogo de instrucciones', BookOpen]]],
  ]
  return (
    <nav className={styles.actionGroup} aria-label="Menú de la aplicación">
      {groups.map(([title, items]) => (
        <AppMenu key={title} title={title} items={items} closing={closing} />
      ))}
    </nav>
  )
}
