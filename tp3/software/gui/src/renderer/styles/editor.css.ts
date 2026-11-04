import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'
import { iconButton } from './controls.css'

export const editor = style({
  position: 'relative',
  height: '100%',
  display: 'flex',
  flexDirection: 'column',
})
export const notice = style({
  padding: '8px 12px',
  color: '#5d6176',
  background: '#f4f4fa',
  borderBottom: '1px solid #e1e3eb',
})
export const diagnostic = style({
  color: '#9e2828',
  background: '#fff0ed',
  font: '12px Inter, sans-serif',
  padding: '3px 12px',
})
globalStyle('.viewrv-selected-occurrence-line, .viewrv-selected-occurrence-line-margin', {
  background: '#e0ddff',
})
globalStyle(`${editor} > section`, { flex: '1 1 0', minHeight: 0 })
globalStyle(`${editor} > div:first-child`, { flexShrink: 0 })
export const breakpointMenu = style({
  position: 'absolute',
  left: 48,
  top: 50,
  zIndex: 30,
  background: '#fff',
  border: `1px solid ${colors.border}`,
  boxShadow: '0 7px 22px #172a4524',
  borderRadius: 8,
  padding: space.md,
  minWidth: 260,
})
export const breakpointOptions = style([breakpointMenu, { padding: 5, minWidth: 230 }])
export const anchoredBreakpoint = style({ overflowY: 'auto', overflowX: 'hidden', padding: 6 })
export const breakpointChoice = style({
  display: 'grid',
  gridTemplateColumns: '66px minmax(0, 1fr) 16px',
  alignItems: 'center',
  gap: 10,
  width: '100%',
  minHeight: 40,
  padding: '8px 10px',
  border: 0,
  borderRadius: 6,
  background: 'transparent',
  color: colors.text,
  textAlign: 'left',
  selectors: {
    '&:hover': { background: '#f4f3ff' },
    '&:focus-visible': {
      background: '#eeedff',
      outline: `2px solid ${colors.accent}`,
      outlineOffset: -2,
    },
    '&[aria-pressed=true]': { color: colors.accent, background: '#f4f3ff' },
  },
})
globalStyle(`${breakpointChoice} > svg`, { color: colors.accent })
globalStyle(`${breakpointChoice} > strong`, {
  display: 'grid',
  placeItems: 'center',
  minHeight: 24,
  padding: '3px 4px',
  borderRadius: 4,
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 11,
  fontWeight: 600,
  background: colors.canvas,
})
globalStyle(`${breakpointChoice}[aria-pressed=true] > strong`, { background: colors.active })
globalStyle(`${breakpointChoice} > span`, { fontSize: 11, color: colors.muted, lineHeight: 1.45 })
export const breakpointOption = style({
  display: 'flex',
  alignItems: 'center',
  gap: space.md,
  width: '100%',
  padding: '10px 11px',
  border: 0,
  borderRadius: 5,
  background: 'transparent',
  color: colors.text,
  textAlign: 'left',
  fontSize: 12,
  selectors: {
    '&:hover, &:focus-visible': { background: '#eeedff', outline: 'none' },
    '&[aria-pressed=true]': { color: colors.accent, background: '#f4f3ff' },
  },
})
globalStyle(`${breakpointOption} strong`, {
  minWidth: 53,
  fontFamily: 'IBM Plex Mono, monospace',
  fontWeight: 500,
})
globalStyle(`${breakpointOption} span`, { color: colors.muted, fontSize: 11, flex: 1 })
globalStyle('.viewrv-source-error', { color: `${colors.error} !important` })
globalStyle('.viewrv-breakpoint', {
  background: 'radial-gradient(circle, #d62291 0 30%, transparent 35%)',
})
globalStyle('.viewrv-stage-line, .viewrv-stage-line-margin', { background: '#f5f3ff' })
globalStyle('.viewrv-stage-badge', {
  color: colors.accent,
  fontSize: 10,
  fontFamily: 'IBM Plex Mono, monospace',
})
globalStyle('.monaco-scrollable-element > .scrollbar > .slider', { borderRadius: 6 })
globalStyle('.viewrv-hover-line, .viewrv-hover-margin', {
  background: '#e8ebf34d',
  boxShadow: 'inset 0 1px #dde2ec66,inset 0 -1px #dde2ec66',
})
globalStyle('.monaco-editor .viewrv-hover-line-number', { color: colors.accent, fontWeight: 600 })
globalStyle('.viewrv-breakpoint-slot', {
  background: 'none',
})
globalStyle('.viewrv-breakpoint-hover', {
  background: 'radial-gradient(circle, transparent 0 3px, #a7a0e7 3px 4px, transparent 4px)',
})
export const breakpointPicker = style({
  position: 'absolute',
  pointerEvents: 'auto',
  display: 'grid',
  placeItems: 'center',
  width: '100%',
  height: '100%',
  padding: 0,
  border: 0,
  borderRadius: 3,
  color: colors.muted,
  background: 'transparent',
  selectors: {
    '&:hover, &:focus-visible': { background: colors.active, color: colors.accent },
    '&:focus-visible': { outline: `1px solid ${colors.accent}` },
  },
})
export const breakpointActions = style({
  position: 'absolute',
  top: 0,
  left: 0,
  overflow: 'hidden',
  pointerEvents: 'none',
})
globalStyle(`.viewrv-breakpoint-hover`, { pointerEvents: 'none' })
globalStyle('.monaco-editor[data-breakpoints-enabled=true] .glyph-margin', { cursor: 'pointer' })
globalStyle('.monaco-editor .suggest-widget, .monaco-editor .suggest-details', {
  borderRadius: 8,
  boxShadow: '0 8px 26px #172a4529',
})
globalStyle('.monaco-editor .suggest-details', {
  boxSizing: 'content-box',
  minWidth: 280,
  maxWidth: 'min(420px, calc(100vw - 32px))',
})
globalStyle('.monaco-editor .suggest-details .docs', {
  whiteSpace: 'normal',
  overflowWrap: 'break-word',
})
globalStyle('.viewrv-editor-overlays', {
  position: 'fixed',
  top: 0,
  left: 0,
  width: 0,
  height: 0,
  zIndex: 90,
})

globalStyle('.monaco-editor[data-breakpoints-enabled=false] .viewrv-breakpoint-hover', {
  background: 'none',
})

// The documentation belongs to the suggestion; it stays open until suggestions close.
globalStyle('.monaco-editor .suggest-details .codicon-close', { display: 'none' })
globalStyle(
  '.monaco-editor .suggest-details.no-type > .monaco-scrollable-element > .body > .docs',
  { marginRight: 0 },
)
export const exampleInfoButton = style([
  iconButton,
  {
    position: 'absolute',
    bottom: 12,
    right: 18,
    zIndex: 10,
    width: 28,
    height: 28,
    background: '#f8f9fc',
    color: colors.muted,
  },
])
export const editorHint = style({
  position: 'absolute',
  bottom: 14,
  left: 12,
  zIndex: 10,
  display: 'flex',
  alignItems: 'center',
  gap: 5,
  fontSize: 11,
  color: colors.muted,
  background: '#f8f9fc',
  padding: '4px 7px',
  borderRadius: 5,
  maxWidth: 'calc(100% - 70px)',
})
globalStyle('.monaco-editor .suggest-details .markdown-docs', { fontSize: 13 })
for (let mask = 1; mask < 16; mask++) {
  const targets = ['IF/ID', 'ID/EX', 'EX/MEM', 'MEM/WB']
    .filter((_, index) => mask & (1 << index))
    .join(' · ')
  globalStyle(`.viewrv-breakpoint-targets-${mask}::before`, {
    content: JSON.stringify(targets),
    position: 'absolute',
    left: 0,
    top: 0,
    color: '#b80078',
    fontFamily: 'IBM Plex Mono, monospace',
    fontSize: 10,
    fontWeight: 500,
  })
}

globalStyle('.monaco-editor [class*="viewrv-breakpoint-targets-"]:empty::before', {
  display: 'none',
})
export const sourceFollowAnchor = style({
  display: 'flex',
  alignItems: 'center',
  paddingLeft: space.sm,
  height: 19,
})
export const sourceFollowButton = style({
  display: 'grid',
  placeItems: 'center',
  width: 22,
  height: 19,
  padding: 0,
  border: 0,
  borderRadius: 4,
  background: 'transparent',
  color: colors.muted,
  cursor: 'pointer',
  selectors: {
    '&:hover': { background: colors.active, color: colors.accent },
    '&:focus-visible': { outline: `2px solid ${colors.accent}`, outlineOffset: 1 },
    '&[aria-pressed=true]': { background: colors.active, color: colors.accent },
  },
})
