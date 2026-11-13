import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'

export const shell = style({
  height: '100%',
  display: 'grid',
  gridTemplateRows: '44px minmax(0, 1fr) 26px',
  overflow: 'hidden',
})
export const header = style({
  position: 'relative',
  display: 'flex',
  alignItems: 'center',
  padding: '0 16px',
  gap: 14,
  background: colors.canvas,
})
export const brand = style({
  display: 'inline-flex',
  alignItems: 'center',
  gap: 3,
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 20,
  fontWeight: 600,
  letterSpacing: '-.7px',
  color: colors.text,
  whiteSpace: 'nowrap',
})
export const brandSeparator = style({
  display: 'inline-block',
  width: 2,
  height: 20,
  background: colors.accent,
  margin: '0 1px',
})
export const content = style({
  display: 'grid',
  gridTemplateColumns: '60px minmax(0, 1fr)',
  minHeight: 0,
})
export const sidebar = style({
  background: colors.canvas,
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  paddingTop: space.sm,
  paddingBottom: space.md,
  gap: 10,
})
export const navButton = style({
  display: 'grid',
  placeItems: 'center',
  padding: 0,
  lineHeight: 0,
  border: '1px solid transparent',
  borderRadius: 8,
  background: 'transparent',
  color: colors.muted,
  width: 42,
  height: 42,
  selectors: {
    '&[aria-pressed=true]': {
      background: colors.active,
      color: colors.accent,
    },
    '&:last-child': { marginTop: 'auto' },
  },
})
globalStyle(`${navButton} svg`, { display: 'block' })
export const windowControls = style({
  display: 'flex',
  alignItems: 'center',
  gap: 0,
  marginRight: -8,
})
export const statusSymbol = style({
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  flexShrink: 0,
  verticalAlign: 'middle',
})
export const fileStatus = style({
  display: 'flex',
  alignItems: 'center',
  gap: space.sm,
  marginLeft: 'auto',
  minWidth: 0,
})
export const statusFileName = style({
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
})
export const loadedImage = style({ display: 'inline-flex', alignItems: 'center', gap: space.sm })
export const statusAction = style({
  display: 'inline-grid',
  placeItems: 'center',
  padding: 0,
  width: 22,
  height: 22,
  border: 0,
  borderRadius: 4,
  background: 'transparent',
  color: colors.muted,
  selectors: {
    '&:hover:not(:disabled)': { background: '#e0ddff', color: colors.accent },
    '&:focus-visible': { outline: `2px solid ${colors.accent}` },
  },
})
export const workspace = style({ position: 'relative', minHeight: 0, minWidth: 0 })
export const appWorkspace = style({ margin: '0 12px 8px 8px' })
export const viewerSurface = style({
  position: 'absolute',
  inset: 0,
  border: `1px solid ${colors.border}`,
  borderRadius: 12,
  overflow: 'hidden',
  background: '#fff',
})
export const status = style({
  padding: '4px 12px',
  background: '#eeeff7',
  color: '#51566e',
  fontSize: 11,
  whiteSpace: 'nowrap',
  minWidth: 0,
})
export const info = style({
  padding: space.xl,
  lineHeight: 1.7,
  height: '100%',
  overflow: 'auto',
  minHeight: 0,
})
export const frame = style({ display: 'block', width: '100%', height: '100%', border: 0 })
export const ide = style({ height: '100%', display: 'flex', flexDirection: 'column', minHeight: 0 })
globalStyle(`${ide} > section`, { flexShrink: 0 })
globalStyle(`${ide} .${workspace}`, { flex: '1 1 300px', minHeight: 160 })
export const toolbar = style({
  display: 'flex',
  flexWrap: 'wrap',
  gap: 6,
  padding: 10,
  borderBottom: '1px solid #dde0ea',
  background: '#fff',
})
globalStyle(`${toolbar} button`, {
  padding: '6px 10px',
  border: '1px solid #d8daea',
  borderRadius: 5,
  background: '#f9f9fd',
  color: '#343856',
})
export const welcome = style({
  position: 'absolute',
  inset: 0,
  display: 'flex',
  justifyContent: 'center',
  flexDirection: 'column',
  maxWidth: 430,
  margin: '0 auto',
  gap: space.md,
  padding: space.xl,
  color: colors.text,
})
export const actionBar = style({
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  minHeight: 44,
  gap: space.md,
  padding: '4px 10px 8px',
  flexShrink: 0,
})
export const welcomeAction = style({
  display: 'flex',
  alignItems: 'center',
  textAlign: 'left',
  gap: 15,
  background: 'transparent',
  border: '1px solid transparent',
  borderRadius: 8,
  padding: '12px 14px',
  color: colors.accent,
  width: '100%',
  selectors: {
    '&:hover, &:focus-visible': { borderColor: '#b9b6e5', background: '#f7f7ff', outline: 'none' },
  },
})
globalStyle(`${welcomeAction} small`, { display: 'block', color: colors.muted, paddingTop: 5 })
globalStyle(`${welcome} h2`, { fontSize: 26, margin: '8px 0', lineHeight: 1.2 })
globalStyle(`${welcome} > p`, { color: colors.muted, fontSize: 14 })
// Shared hover feedback for application chrome; keyboard focus stays independently visible.
globalStyle(`${sidebar} button, ${header} button, ${actionBar} button`, {
  transition: 'box-shadow 140ms ease, background-color 140ms ease',
})
globalStyle(
  `${sidebar} button:hover:not(:disabled), ${header} button:hover:not(:disabled), ${actionBar} button:hover:not(:disabled)`,
  {
    boxShadow: '0 2px 5px #232d3b24',
  },
)
globalStyle(`${sidebar} button:hover:not(:disabled)`, { background: colors.active })
globalStyle(`${sidebar} button, ${header} button, ${actionBar} button`, {
  '@media': { '(prefers-reduced-motion: reduce)': { transition: 'none' } },
})

export const windowTitle = style({
  position: 'absolute',
  left: '50%',
  top: '50%',
  transform: 'translate(-50%,-50%)',
  fontSize: 12,
  color: colors.muted,
  pointerEvents: 'none',
  '@media': { '(max-width:700px)': { display: 'none' } },
})

export const previewBadge = style({
  position: 'absolute',
  right: 140,
  top: 10,
  padding: '5px 8px',
  fontSize: 11,
  lineHeight: 1.3,
  borderRadius: 6,
  color: colors.accent,
  background: '#e9e5ff',
})
