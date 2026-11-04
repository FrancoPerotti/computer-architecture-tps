import { globalFontFace, globalStyle, style } from '@vanilla-extract/css'

globalStyle('*', { boxSizing: 'border-box' })
import { colors, space } from './ui-tokens'
export { colors } from './ui-tokens'
globalStyle('body', {
  margin: 0,
  color: colors.text,
  fontFamily: 'Inter, sans-serif',
  fontSize: 13,
  background: colors.canvas,
})
globalStyle('button', { font: 'inherit', cursor: 'pointer' })
globalFontFace('Inter', { src: 'url("viewrv://app/content/fonts/inter-400.ttf")', fontWeight: 400 })
globalFontFace('Inter', { src: 'url("viewrv://app/content/fonts/inter-600.ttf")', fontWeight: 600 })
globalFontFace('IBM Plex Mono', {
  src: 'url("viewrv://app/content/fonts/ibm-plex-mono-400.ttf")',
  fontWeight: 400,
})
globalFontFace('IBM Plex Mono', {
  src: 'url("viewrv://app/content/fonts/ibm-plex-mono-600.ttf")',
  fontWeight: 600,
})
globalStyle('html, body, #root', { height: '100%', minHeight: 0 })
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
globalStyle('button:disabled', { opacity: 0.5, cursor: 'default' })
export const error = style({
  padding: '8px 12px',
  background: '#fff0ec',
  color: '#8c2929',
  display: 'flex',
  justifyContent: 'space-between',
  gap: 10,
})
export const diagnostic = style({
  color: '#9e2828',
  background: '#fff0ed',
  font: '12px Inter, sans-serif',
  padding: '3px 12px',
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
export const assembly = style({
  padding: '10px 18px',
  background: '#f2f3fb',
  borderTop: '1px solid #d9dce9',
  maxHeight: 170,
  overflow: 'auto',
})
export const recovery = style({
  padding: '10px 18px',
  background: '#fff',
  borderTop: '1px solid #d9dce9',
  maxHeight: 180,
  overflow: 'auto',
})
globalStyle(`${recovery} button`, { margin: '6px 0 0 12px' })
export const modal = style({
  position: 'fixed',
  inset: 0,
  zIndex: 100,
  background: '#20263d55',
  display: 'grid',
  placeItems: 'center',
})
export const modalBody = style({
  background: '#fff',
  borderRadius: 12,
  width: 'min(680px, 92vw)',
  maxHeight: 'calc(100dvh - 40px)',
  overflow: 'hidden',
  padding: 0,
  display: 'flex',
  flexDirection: 'column',
  boxShadow: '0 15px 80px #20263d44',
})
export const dialogScroller = style({ padding: '0 24px 24px', minHeight: 0, overflow: 'auto' })
export const dialogHeader = style({
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: space.lg,
  padding: space.xl,
  flexShrink: 0,
})
globalStyle(`${dialogHeader} h2`, { margin: 0, fontSize: 20, lineHeight: 1.4 })
export const dialogContent = style({ display: 'grid', gap: space.xl, minWidth: 0 })
globalStyle(`${dialogContent} > p`, { margin: 0, lineHeight: 1.6 })
globalStyle(`${dialogScroller} > h2`, { margin: '0 30px 20px 0', fontSize: 21 })
export const dialogPopup = style({
  position: 'fixed',
  left: '50%',
  top: '50%',
  transform: 'translate(-50%, -50%)',
  zIndex: 101,
})
globalStyle(`${modalBody} button`, { padding: '7px 12px', margin: '10px 8px 0 0' })
globalStyle(`${modalBody} label`, { display: 'block', margin: '10px 0' })
export const form = style({
  display: 'flex',
  flexDirection: 'column',
  width: '100%',
  maxWidth: 760,
  gap: space.md,
})
globalStyle(`${form} label`, {
  display: 'grid',
  gridTemplateColumns: 'minmax(0, 1fr) minmax(120px, 200px)',
  alignItems: 'center',
  gap: 20,
  '@media': { '(max-width: 600px)': { gridTemplateColumns: 'minmax(0, 1fr) 120px', gap: 10 } },
})
globalStyle(`${form} input, ${form} select`, {
  font: 'inherit',
  padding: 7,
  border: '1px solid #d9dce9',
  borderRadius: 5,
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
export const actionGroup = style({ display: 'flex', alignItems: 'center', gap: 6 })
export const iconButton = style({
  display: 'inline-grid',
  placeItems: 'center',
  width: 34,
  height: 32,
  padding: 0,
  lineHeight: 0,
  flexShrink: 0,
  border: '1px solid transparent',
  borderRadius: 6,
  background: 'transparent',
  color: '#475569',
  selectors: {
    '&:hover:not(:disabled)': { background: '#e4e7ee', borderColor: colors.border },
    '&:focus-visible': { outline: `2px solid ${colors.accent}`, outlineOffset: 2 },
  },
})
export const badge = style({
  display: 'inline-block',
  padding: '5px 8px',
  background: colors.canvas,
  color: colors.muted,
  borderRadius: 5,
  fontSize: 11,
})
export const muted = style({ color: colors.muted, fontSize: 11, lineHeight: 1.7 })
export const menuPopup = style({
  background: '#fff',
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  padding: 5,
  zIndex: 150,
  minWidth: 220,
  boxShadow: '0 8px 28px #172a4524',
  outline: 'none',
})
export const menuItem = style({
  display: 'flex',
  alignItems: 'center',
  gap: 9,
  padding: '8px 12px',
  fontSize: 12,
  borderRadius: 4,
  cursor: 'pointer',
  selectors: {
    '&[data-highlighted]': { background: '#eeedff', color: colors.accent },
    '&[data-disabled]': { opacity: 0.45, cursor: 'default' },
  },
})
export const menuTrigger = style({
  border: 0,
  background: 'transparent',
  padding: '6px 9px',
  color: colors.muted,
  fontSize: 12,
  borderRadius: 4,
  selectors: { '&[data-popup-open]': { background: '#e0e4ed' } },
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
export const results = style({
  height: '100%',
  overflow: 'auto',
  padding: space.xl,
  background: '#fff',
  color: colors.text,
  containerType: 'inline-size',
  containerName: 'processor-results',
})
globalStyle(`${results} > * + *`, { marginTop: space.xl })
globalStyle(`${results} > details`, {
  margin: '24px 0',
  border: `1px solid ${colors.border}`,
  borderRadius: 6,
  padding: space.lg,
})
globalStyle(`${results} summary`, {
  cursor: 'pointer',
  fontSize: 13,
  padding: '4px 0',
  fontWeight: 600,
})
globalStyle(`${results} h2`, { fontSize: 19, display: 'flex', gap: 10, alignItems: 'center' })
export const resultHeader = style({
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  gap: 14,
  marginBottom: 0,
})
export const cycleCount = style({
  display: 'inline-flex',
  alignItems: 'center',
  gap: space.sm,
  color: colors.muted,
})
globalStyle(`${cycleCount} strong`, { color: colors.text })
export const graphView = style({
  height: '100%',
  display: 'flex',
  flexDirection: 'column',
  minHeight: 0,
  background: '#fff',
})
export const graphHeader = style({
  display: 'flex',
  gap: 10,
  alignItems: 'center',
  flexWrap: 'wrap',
  padding: '8px 12px',
  borderBottom: `1px solid ${colors.border}`,
  fontSize: 11,
})
export const graphCanvas = style({
  position: 'relative',
  flex: '1 1 240px',
  minHeight: 180,
  overflow: 'hidden',
})
export const graphInspector = style({
  padding: '10px 14px',
  borderTop: `1px solid ${colors.border}`,
  maxHeight: '38%',
  overflow: 'auto',
  flex: '0 0 auto',
})
export const inspectorControls = style({
  display: 'flex',
  alignItems: 'center',
  flexWrap: 'wrap',
  gap: space.sm,
})
globalStyle(`${inspectorControls} select`, {
  maxWidth: '100%',
  font: 'inherit',
  padding: 5,
  border: `1px solid ${colors.border}`,
  borderRadius: 5,
  background: '#fff',
})
export const selectedLatch = style({ outline: `2px solid ${colors.accent}`, outlineOffset: -2 })
globalStyle('.viewrv-selected-occurrence-line, .viewrv-selected-occurrence-line-margin', {
  background: '#e0ddff',
})
globalStyle(`${resultHeader} strong`, {
  display: 'block',
  fontSize: 24,
  fontWeight: 400,
  fontFamily: 'IBM Plex Mono, monospace',
})
export const cellLabel = style({
  fontSize: 10,
  color: colors.muted,
  display: 'block',
  overflowWrap: 'anywhere',
})
export const valueCell = style({
  display: 'flex',
  flexDirection: 'column',
  gap: 3,
  background: colors.canvas,
  borderRadius: 4,
  padding: '5px 7px',
  minWidth: 0,
  position: 'relative',
  isolation: 'isolate',
  overflow: 'hidden',
})
export const changedCell = style([valueCell, { background: colors.changed }])
export const valueUnderlay = style({
  position: 'absolute',
  inset: 0,
  zIndex: -2,
  opacity: 0,
  pointerEvents: 'none',
})
export const valueCurtain = style({
  position: 'absolute',
  inset: 0,
  zIndex: -1,
  opacity: 0,
  pointerEvents: 'none',
  transformOrigin: 'left center',
})
globalStyle(`${valueCell} code`, {
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 11,
  overflowWrap: 'anywhere',
})
globalStyle(`${valueCell} select`, {
  position: 'absolute',
  right: 3,
  top: 2,
  width: 17,
  font: '10px Inter, sans-serif',
  color: colors.muted,
  background: '#fff',
  border: 0,
  opacity: 0,
})
globalStyle(`${valueCell}:hover select, ${valueCell}:focus-within select`, { opacity: 1 })
globalStyle(`${editor} > section`, { flex: '1 1 0', minHeight: 0 })
globalStyle(`${editor} > div:first-child`, { flexShrink: 0 })
export const registerGrid = style({
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(110px, 1fr))',
  gap: space.sm,
  marginTop: space.lg,
})
export const latchGrid = style({
  display: 'grid',
  gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
  gap: space.sm,
  paddingBottom: space.xs,
  '@container': {
    'processor-results (max-width: 580px)': { gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' },
  },
})
export const latchCard = style({
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  padding: space.md,
  minWidth: 0,
})
export const latchHeading = style({
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  gap: 6,
  fontSize: 12,
  fontWeight: 500,
  lineHeight: 1.5,
  margin: '0 0 12px',
})
export const instructionStatus = style({
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  width: 18,
  height: 18,
  flexShrink: 0,
})
export const validIcon = style({ color: colors.success, flexShrink: 0 })
export const invalidIcon = style({ color: colors.error, flexShrink: 0 })
export const emptyIcon = style({ color: colors.muted, flexShrink: 0 })
export const latchSource = style({
  display: 'flex',
  flexWrap: 'wrap',
  alignItems: 'baseline',
  gap: 6,
  margin: '12px 0',
  fontSize: 11,
  lineHeight: 1.6,
})
globalStyle(`${latchSource} code`, {
  fontFamily: 'IBM Plex Mono, monospace',
  overflowWrap: 'anywhere',
  color: colors.text,
})
globalStyle(`${latchSource} span`, {
  marginLeft: 'auto',
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 10,
  color: colors.muted,
})
globalStyle(`${latchCard} > div`, { marginTop: 5 })
export const hitLatch = style([
  latchCard,
  { borderColor: '#d62291', boxShadow: '0 0 0 1px #d6229120' },
])
export const persistentWarning = style({
  background: '#fff7e8',
  border: '1px solid #ead6a7',
  padding: space.md,
  borderRadius: 6,
  lineHeight: 1.6,
})
export const breakpointNotice = style({
  display: 'flex',
  alignItems: 'center',
  flexWrap: 'wrap',
  gap: space.sm,
  padding: '10px 12px',
  width: 'fit-content',
  maxWidth: '100%',
  color: colors.text,
  background: colors.functionalSoft,
  borderRadius: 8,
})
globalStyle(`${breakpointNotice} > svg`, { color: colors.functional, flexShrink: 0 })
globalStyle(`${breakpointNotice} ul`, {
  display: 'flex',
  alignItems: 'center',
  flexWrap: 'wrap',
  gap: space.sm,
  padding: 0,
  margin: 0,
  listStyle: 'none',
})
globalStyle(`${breakpointNotice} li`, {
  display: 'inline-flex',
  alignItems: 'center',
  gap: space.sm,
  color: colors.functional,
})
globalStyle(`${breakpointNotice} code`, { fontSize: 11, fontFamily: 'IBM Plex Mono, monospace' })
export const emptyCapture = style({
  display: 'grid',
  gridTemplateColumns: '36px minmax(0, 1fr)',
  alignItems: 'start',
  gap: space.lg,
  padding: space.xl,
  border: `1px solid ${colors.border}`,
  borderRadius: 10,
  background: '#fafbfe',
  color: colors.muted,
  textAlign: 'left',
})
export const emptyCaptureIcon = style({
  display: 'grid',
  placeItems: 'center',
  width: 36,
  height: 36,
  background: '#eeedff',
  color: colors.accent,
  borderRadius: 8,
})
globalStyle(`${emptyCapture} h2`, {
  fontSize: 15,
  color: colors.text,
  lineHeight: 1.45,
  margin: '0 0 8px',
})
globalStyle(`${emptyCapture} p`, { margin: 0, fontSize: 12, lineHeight: 1.6, maxWidth: '48ch' })
export const emptyCaptureHint = style({
  selectors: { [`${emptyCapture} &`]: { marginTop: 8, fontSize: 11 } },
})
export const memoryFilter = style({
  display: 'flex',
  alignItems: 'center',
  gap: 10,
  paddingTop: 10,
})
export const translation = style({ width: '100%', borderCollapse: 'collapse', fontSize: 12 })
globalStyle(`${translation} td, ${translation} th`, {
  padding: '12px 8px',
  borderBottom: `1px solid ${colors.border}`,
  textAlign: 'left',
})
export const toastStack = style({
  position: 'fixed',
  right: 24,
  bottom: 44,
  zIndex: 80,
  width: 'min(365px, calc(100vw - 90px))',
  display: 'flex',
  flexDirection: 'column',
  gap: space.sm,
  pointerEvents: 'none',
})
export const toast = style({
  display: 'grid',
  gridTemplateColumns: '28px minmax(0, 1fr) 24px',
  alignItems: 'start',
  gap: 10,
  border: `1px solid ${colors.border}`,
  background: '#fff',
  boxShadow: '0 5px 20px #172a4524',
  borderRadius: 10,
  padding: 14,
  pointerEvents: 'auto',
})
export const toastIcon = style({
  display: 'grid',
  placeItems: 'center',
  width: 28,
  height: 28,
  borderRadius: 7,
  background: '#eeedff',
  color: colors.accent,
})
globalStyle(`${toast}[data-kind=error] .${toastIcon}`, {
  background: '#fff0f0',
  color: colors.error,
})
globalStyle(`${toast}[data-kind=success] .${toastIcon}`, {
  background: '#edf7f1',
  color: colors.success,
})
export const toastContent = style({ minWidth: 0, paddingTop: 3 })
export const toastMessage = style({
  margin: 0,
  color: colors.text,
  fontSize: 12,
  fontWeight: 600,
  lineHeight: 1.55,
  overflowWrap: 'anywhere',
})
export const toastClose = style([iconButton, { width: 24, height: 24, color: colors.muted }])
globalStyle(`${toastContent} details`, { marginTop: 8 })
globalStyle(`${toastContent} summary`, { fontSize: 11, color: colors.muted, padding: '3px 0' })
globalStyle(`${toast} pre`, {
  whiteSpace: 'pre-wrap',
  fontSize: 10,
  maxHeight: 160,
  overflow: 'auto',
  margin: '8px 0 0',
  padding: 10,
  background: colors.canvas,
  borderRadius: 6,
  lineHeight: 1.6,
})
export const errorText = style({ color: colors.error })
export const successText = style({ color: colors.success })
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
export const exampleAbout = style({
  padding: '10px 16px',
  background: '#f4f3ff',
  borderBottom: `1px solid ${colors.border}`,
  flexShrink: 0,
  maxHeight: '35%',
  overflow: 'auto',
})
export const preferenceCard = style({
  padding: space.lg,
  minHeight: 66,
  border: `1px solid ${colors.border}`,
  borderRadius: 9,
  background: '#fff',
})
globalStyle(`${preferenceCard} > span`, { display: 'flex', alignItems: 'center', gap: 10 })
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
globalStyle('.flexlayout__layout', {
  isolation: 'isolate',
  vars: {
    '--flexlayout-font-family': 'Inter, sans-serif',
    '--flexlayout-font-size': '12px',
    '--flexlayout-color-background': colors.canvas,
    '--flexlayout-color-base': colors.canvas,
    '--flexlayout-color-text': colors.text,
    '--flexlayout-color-tabset-background': colors.canvas,
    '--flexlayout-color-tabset-background-selected': colors.canvas,
    '--flexlayout-color-tabset-background-maximized': colors.canvas,
    '--flexlayout-color-tabset-divider-line': colors.border,
    '--flexlayout-color-tab-content': '#fff',
    '--flexlayout-color-tab-selected': colors.text,
    '--flexlayout-color-tab-selected-background': '#fff',
    '--flexlayout-color-tab-unselected': colors.muted,
    '--flexlayout-color-tab-unselected-background': '#f7f8fb',
    '--flexlayout-color-splitter': colors.canvas,
  },
})
globalStyle('.flexlayout__tabset', {
  border: `1px solid ${colors.border}`,
  borderRadius: 12,
  overflow: 'hidden',
})
globalStyle('.flexlayout__tabset_container', {
  borderRadius: 12,
  overflow: 'hidden',
  background: colors.canvas,
})
globalStyle('.flexlayout__tabset_tabbar_outer_top', {
  borderRadius: '12px 12px 0 0',
  paddingTop: 2,
  borderBottom: 'none',
})
globalStyle('.flexlayout__tabset_tabbar_outer_bottom', { borderRadius: '0 0 12px 12px' })
globalStyle('.flexlayout__tab', {
  borderRadius: '0 0 12px 12px',
  overflow: 'hidden',
  clipPath: 'inset(0 round 0 0 12px 12px)',
})
globalStyle('.flexlayout__tab_moveable', { borderRadius: '0 0 12px 12px' })
globalStyle('.flexlayout__tab_button', {
  position: 'relative',
  fontSize: 12,
  padding: '8px 12px',
  borderRadius: '8px 8px 0 0',
})
globalStyle('.flexlayout__tab_button--selected', { zIndex: 1 })
globalStyle('.flexlayout__tab_button--selected::before, .flexlayout__tab_button--selected::after', {
  content: '""',
  position: 'absolute',
  bottom: 0,
  width: 8,
  height: 8,
  pointerEvents: 'none',
})
globalStyle('.flexlayout__tab_button--selected::before', {
  left: -8,
  borderBottomRightRadius: 8,
  boxShadow: '4px 4px 0 4px #fff',
})
globalStyle('.flexlayout__tab_button--selected::after', {
  right: -8,
  borderBottomLeftRadius: 8,
  boxShadow: '-4px 4px 0 4px #fff',
})
globalStyle('.flexlayout__tab_toolbar_button', {
  display: 'inline-grid',
  placeItems: 'center',
  padding: 3,
  color: colors.muted,
})

export const exampleResults = style({ display: 'grid', gap: space.md, minWidth: 0 })
globalStyle(`${exampleResults} > p`, { margin: 0 })
export const exampleList = style({
  maxHeight: 'min(55vh, 440px)',
  overflow: 'auto',
  margin: 0,
  display: 'grid',
  gap: space.sm,
  paddingRight: space.xs,
})
globalStyle(`${exampleList} button`, {
  display: 'flex',
  alignItems: 'center',
  gap: space.md,
  width: '100%',
  textAlign: 'left',
  padding: space.lg,
  margin: 0,
  border: `1px solid ${colors.border}`,
  borderRadius: 8,
  background: '#fff',
  color: colors.text,
})
globalStyle(`${exampleList} button:hover, ${exampleList} button:focus-visible`, {
  background: '#f5f4ff',
  borderColor: '#b9b4eb',
  outline: 'none',
})
globalStyle(`${exampleList} p`, {
  margin: '4px 0 0',
  color: colors.muted,
  fontSize: 12,
  lineHeight: 1.5,
})
export const exampleFilters = style({
  display: 'grid',
  gridTemplateColumns: 'minmax(0, 1fr) auto',
  gap: space.md,
  '@media': { '(max-width: 500px)': { gridTemplateColumns: '1fr' } },
})
globalStyle(`${exampleFilters} label`, { margin: 0 })
globalStyle(`${exampleFilters} input, ${exampleFilters} select`, {
  height: 38,
  font: 'inherit',
  padding: '8px 10px',
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  background: '#fff',
  color: colors.text,
  minWidth: 0,
  maxWidth: '100%',
})
globalStyle(`${exampleFilters} input:focus-visible, ${exampleFilters} select:focus-visible`, {
  outline: `2px solid ${colors.accent}`,
  outlineOffset: 2,
})
export const searchField = style({
  position: 'relative',
  display: 'flex',
  alignItems: 'center',
  minWidth: 0,
})
globalStyle(`${searchField} > svg`, {
  position: 'absolute',
  left: 11,
  top: '50%',
  transform: 'translateY(-50%)',
  color: colors.muted,
  pointerEvents: 'none',
})
globalStyle(`${searchField} > input`, { width: '100%', paddingLeft: 35 })
export const runGroup = style({
  position: 'relative',
  display: 'inline-flex',
  alignItems: 'center',
  gap: 0,
  background: 'transparent',
  selectors: {
    '&::after': {
      content: '""',
      position: 'absolute',
      left: 28,
      top: 9,
      height: 14,
      width: 1,
      background: '#a9b1c1',
      pointerEvents: 'none',
    },
  },
})
export const runDropdown = style([iconButton, { width: 22, height: 32 }])
globalStyle(`${runGroup} > span > button`, { width: 28, height: 32 })
export const preferenceNote = style({ fontSize: 12, color: colors.muted, margin: '4px 0' })
globalStyle(`${preferenceCard} input[type=checkbox]`, {
  justifySelf: 'end',
  width: 18,
  height: 18,
  accentColor: colors.accent,
  cursor: 'pointer',
})
globalStyle(`${preferenceCard} select, ${preferenceCard} input:not([type=checkbox])`, {
  width: '100%',
  minWidth: 0,
})
export const referencePanel = style({
  height: '100%',
  overflow: 'auto',
  padding: 20,
  lineHeight: 1.65,
  background: '#fff',
})
globalStyle(`${referencePanel} > h2`, { fontSize: 19, marginTop: 0 })
export const catalog = style({
  height: '100%',
  minHeight: 0,
  overflow: 'auto',
  padding: space.xl,
  background: '#fff',
  containerType: 'inline-size',
  containerName: 'instruction-catalog',
})
export const catalogBody = style({
  display: 'grid',
  gap: space.xl,
  maxWidth: 960,
  margin: '0 auto',
  minWidth: 0,
})
export const catalogTools = style({ display: 'grid', gap: space.md })
export const catalogEntries = style({ display: 'grid', gap: space.md, minWidth: 0 })
export const catalogCount = style({ fontSize: 11, color: colors.muted, lineHeight: 1.5, margin: 0 })
export const catalogHeader = style({
  display: 'flex',
  alignItems: 'center',
  gap: space.md,
  margin: 0,
})
globalStyle(`${catalogHeader} > svg`, {
  color: colors.accent,
  background: '#f0eeff',
  padding: 9,
  width: 40,
  height: 40,
  borderRadius: 9,
})
globalStyle(`${catalogHeader} h2`, { fontSize: 20, margin: 0 })
globalStyle(`${catalogHeader} p`, {
  margin: '4px 0 0',
  color: colors.muted,
  fontSize: 12,
  lineHeight: 1.5,
})
export const catalogFilters = style({ display: 'flex', flexWrap: 'wrap', gap: space.sm, margin: 0 })
globalStyle(`${catalogFilters} button`, {
  padding: '6px 10px',
  border: `1px solid ${colors.border}`,
  borderRadius: 20,
  background: '#fff',
  color: colors.muted,
  fontSize: 12,
})
globalStyle(`${catalogFilters} button[aria-pressed=true]`, {
  background: colors.active,
  color: colors.accent,
  borderColor: '#c8c1f5',
})
export const catalogGrid = style({
  display: 'grid',
  gridTemplateColumns: 'minmax(0,1fr)',
  gap: space.lg,
})
export const instructionCard = style({
  display: 'grid',
  gap: space.lg,
  border: `1px solid ${colors.border}`,
  borderRadius: 9,
  padding: space.xl,
  background: '#fcfcff',
  minWidth: 0,
  '@container': { 'instruction-catalog (max-width:480px)': { padding: space.lg } },
})
globalStyle(`${instructionCard} header`, {
  display: 'flex',
  justifyContent: 'space-between',
  gap: space.sm,
  alignItems: 'center',
})
globalStyle(`${instructionCard} code`, {
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 16,
  fontWeight: 600,
  color: colors.accent,
})
globalStyle(`${instructionCard} p`, { fontSize: 13, lineHeight: 1.65, margin: 0, maxWidth: '68ch' })
globalStyle(`${instructionCard} h3`, { margin: 0, fontSize: 16, lineHeight: 1.5 })
globalStyle(`${instructionCard} small`, { fontSize: 10, color: colors.muted })
globalStyle('*::-webkit-scrollbar', { width: 8, height: 8 })
globalStyle('*::-webkit-scrollbar-track', { background: 'transparent', borderRadius: 20 })
globalStyle('*::-webkit-scrollbar-thumb', {
  background: '#b6bfcd',
  border: '2px solid transparent',
  backgroundClip: 'padding-box',
  borderRadius: 20,
})
globalStyle('*::-webkit-scrollbar-thumb:hover', { backgroundColor: '#929fb2' })
globalStyle('*::-webkit-scrollbar-corner', { background: 'transparent' })
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
globalStyle(`${menuTrigger}:hover:not(:disabled)`, { background: '#e4e7ee' })
globalStyle(`${sidebar} button, ${header} button, ${actionBar} button`, {
  '@media': { '(prefers-reduced-motion: reduce)': { transition: 'none' } },
})
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
export const recoveryList = style({ display: 'grid', gap: 10 })
export const recoveryRow = style({
  display: 'flex',
  alignItems: 'center',
  flexWrap: 'wrap',
  gap: space.sm,
  padding: 14,
  border: `1px solid ${colors.border}`,
  borderRadius: 9,
})
globalStyle(`${recoveryRow} > span`, { flex: '1 1 180px', overflowWrap: 'anywhere' })
export const primaryButton = style({
  display: 'inline-flex',
  justifyContent: 'center',
  alignItems: 'center',
  gap: space.sm,
  border: `1px solid ${colors.accent}`,
  borderRadius: 7,
  background: colors.accent,
  color: '#fff',
  padding: '9px 13px',
  fontWeight: 500,
  selectors: {
    '&:hover:not(:disabled)': { background: '#3730a3' },
    '&:focus-visible': { outline: `2px solid ${colors.accent}`, outlineOffset: 3 },
  },
})
export const secondaryButton = style([
  primaryButton,
  {
    background: '#fff',
    borderColor: colors.border,
    color: colors.text,
    selectors: { '&:hover:not(:disabled)': { background: '#f4f3ff', borderColor: '#b9b4eb' } },
  },
])
export const boardPanel = style({ display: 'flex', flexDirection: 'column', gap: space.xl })
globalStyle(`${boardPanel} p`, { margin: 0, lineHeight: 1.6 })
globalStyle(`${boardPanel} button`, { margin: 0 })
export const boardHero = style({ display: 'flex', alignItems: 'center', gap: space.md })
export const boardIcon = style({
  display: 'grid',
  placeItems: 'center',
  width: 44,
  height: 44,
  background: '#eeecff',
  borderRadius: 10,
  color: colors.accent,
  flexShrink: 0,
})
globalStyle(`${boardHero} strong`, { display: 'block', fontSize: 16, marginBottom: space.xs })
export const connectionBadge = style({
  marginLeft: 'auto',
  padding: '6px 9px',
  fontSize: 11,
  borderRadius: 20,
  color: colors.muted,
  background: colors.canvas,
  whiteSpace: 'nowrap',
  selectors: { '&[data-connected=true]': { color: '#1b6f4b', background: '#e8f6ee' } },
})
export const boardSummary = style({
  display: 'grid',
  gridTemplateColumns: 'repeat(2,minmax(0,1fr))',
  gap: space.lg,
  padding: space.lg,
  margin: 0,
  border: `1px solid ${colors.border}`,
  borderRadius: 9,
  background: '#fafbfe',
})
globalStyle(`${boardSummary} dt`, { fontSize: 11, color: colors.muted, marginBottom: space.xs })
globalStyle(`${boardSummary} dd`, {
  margin: 0,
  fontSize: 12,
  lineHeight: 1.5,
  overflowWrap: 'anywhere',
})
export const boardDestinations = style({ display: 'grid', gap: space.lg })
export const boardSectionHeading = style({
  display: 'flex',
  justifyContent: 'space-between',
  alignItems: 'center',
  gap: 10,
})
globalStyle(`${boardSectionHeading} h3`, { fontSize: 13, margin: 0 })
export const boardFields = style({ display: 'grid', gap: space.md })
globalStyle(`${boardFields} label`, {
  display: 'grid',
  gridTemplateColumns: '136px minmax(0,1fr)',
  alignItems: 'center',
  gap: space.lg,
  margin: 0,
  fontSize: 12,
  '@media': { '(max-width:500px)': { gridTemplateColumns: '1fr', gap: space.sm } },
})
globalStyle(`${boardFields} select`, {
  width: '100%',
  minWidth: 0,
  font: 'inherit',
  padding: '9px 10px',
  color: colors.text,
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  background: '#fff',
})
export const boardHelp = style({
  display: 'flex',
  gap: 9,
  color: colors.muted,
  fontSize: 12,
  lineHeight: 1.6,
})
globalStyle(`${boardHelp} > svg`, { flexShrink: 0, marginTop: 2 })
export const boardActions = style({ display: 'flex', flexWrap: 'wrap', gap: space.sm })
globalStyle(`${boardActions} > button`, { minHeight: 36 })
export const boardFeedback = style({
  padding: '11px 13px',
  borderRadius: 8,
  fontSize: 12,
  background: '#f1f3fa',
  color: colors.text,
  selectors: {
    '&[data-tone=success]': { background: '#edf8f1', color: '#1b6f4b' },
    '&[data-tone=error]': { background: '#fff0f1', color: colors.error },
  },
})
export const boardGuide = style({
  alignSelf: 'flex-start',
  display: 'inline-flex',
  alignItems: 'center',
  gap: 7,
  border: 0,
  background: 'transparent',
  color: colors.accent,
  fontSize: 12,
  padding: '2px 0',
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
globalStyle(`${iconButton} > svg`, { display: 'block', flexShrink: 0 })
export const instructionIntro = style({ display: 'grid', gap: space.md })
export const instructionSyntax = style({
  display: 'block',
  padding: '12px 16px',
  borderRadius: 6,
  background: '#f0eefc',
  overflowWrap: 'anywhere',
  margin: 0,
})
export const instructionDetails = style({
  display: 'grid',
  gridTemplateColumns: 'minmax(0,1fr)',
  gap: space.xl,
  marginTop: space.sm,
  '@container': {
    'instruction-catalog (min-width:760px)': { gridTemplateColumns: 'minmax(0,3fr) minmax(0,2fr)' },
  },
})
globalStyle(`${instructionDetails} h4`, {
  fontSize: 11,
  color: colors.muted,
  fontWeight: 600,
  margin: '0 0 8px',
})
export const instructionOperands = style({ margin: 0, display: 'grid', gap: space.md })
globalStyle(`${instructionOperands} > div`, {
  display: 'grid',
  gridTemplateColumns: '64px minmax(0,1fr)',
  gap: space.md,
  alignItems: 'baseline',
})
globalStyle(`${instructionOperands} dt code`, { fontSize: 12 })
globalStyle(`${instructionOperands} dd`, { margin: 0, fontSize: 12, lineHeight: 1.65 })
export const instructionExample = style({
  margin: 0,
  padding: '12px 14px',
  background: '#f5f6fa',
  border: `1px solid ${colors.border}`,
  borderRadius: 6,
  whiteSpace: 'pre-wrap',
  overflowWrap: 'anywhere',
})
globalStyle(`${instructionExample} code`, { fontSize: 13, color: colors.text, fontWeight: 400 })
export const instructionNotes = style({
  fontSize: 12,
  lineHeight: 1.65,
  color: colors.muted,
  paddingLeft: 18,
  margin: 0,
})
globalStyle('.monaco-editor .suggest-details .markdown-docs', { fontSize: 13 })

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

export const globalState = style({
  background: '#fafbfe',
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  padding: space.lg,
})
globalStyle(`${globalState} > h2`, { fontSize: 14, fontWeight: 600, color: colors.text, margin: 0 })
globalStyle(`${globalState} > div`, { marginTop: space.lg, gridAutoRows: '1fr' })
export const sectionIntro = style({
  fontSize: 11,
  lineHeight: 1.65,
  color: colors.muted,
  margin: 0,
})
export const exampleGuide = style({
  display: 'grid',
  gap: space.lg,
  paddingTop: space.xl,
  fontSize: 12,
  lineHeight: 1.65,
  containerType: 'inline-size',
  containerName: 'example-guide',
})
export const guideTitle = style({ display: 'flex', gap: 11, alignItems: 'flex-start' })
globalStyle(`${guideTitle} > span`, {
  display: 'grid',
  placeItems: 'center',
  width: 36,
  height: 36,
  borderRadius: 8,
  background: '#eeecff',
  color: colors.accent,
  flexShrink: 0,
})
globalStyle(`${guideTitle} h3`, {
  fontSize: 16,
  lineHeight: 1.3,
  margin: '0 0 5px',
  fontWeight: 600,
})
globalStyle(`${guideTitle} p`, { margin: 0, color: colors.muted })
export const guideComparison = style({
  display: 'grid',
  gridTemplateColumns: 'minmax(0, 1fr)',
  alignItems: 'start',
  gap: space.lg,
  '@container': {
    'example-guide (min-width: 760px)': { gridTemplateColumns: 'repeat(2, minmax(0, 1fr))' },
  },
})
export const expectedCard = style({
  padding: space.lg,
  border: '1px solid #d8d3f5',
  borderRadius: 8,
  background: '#f7f6ff',
  minWidth: 0,
})
export const receivedCard = style({
  padding: space.lg,
  border: `1px solid ${colors.border}`,
  borderRadius: 8,
  background: '#fafbfe',
  minWidth: 0,
  selectors: { '&[data-stale=true]': { borderColor: '#ead6a7', background: '#fffaf0' } },
})
globalStyle(`${expectedCard} h4, ${receivedCard} h4`, {
  fontSize: 13,
  margin: 0,
  fontWeight: 600,
})
globalStyle(`${expectedCard} h4`, { color: colors.accent })
globalStyle(`${receivedCard} > header, ${expectedCard} > header`, {
  display: 'flex',
  alignItems: 'baseline',
  justifyContent: 'space-between',
  gap: space.sm,
  flexWrap: 'wrap',
})
export const guideExpectations = style({
  paddingLeft: 18,
  margin: '12px 0 0',
  display: 'grid',
  gap: space.sm,
})
globalStyle(`${guideExpectations} li`, { paddingLeft: 2, margin: 0 })
export const guideCycle = style({
  border: `1px solid ${colors.border}`,
  borderRadius: 8,
  padding: space.lg,
  minWidth: 0,
})
globalStyle(`${guideCycle} h4`, { fontSize: 13, margin: 0, fontWeight: 600 })
globalStyle(`${guideCycle} p`, { margin: '12px 0 0' })
export const guideTable = style({
  width: '100%',
  borderCollapse: 'collapse',
  fontSize: 12,
  marginTop: space.lg,
})
globalStyle(`${guideTable} th, ${guideTable} td`, {
  padding: '8px 4px',
  borderBottom: '1px solid #e1e4ed',
  textAlign: 'left',
  verticalAlign: 'top',
  overflowWrap: 'anywhere',
})
globalStyle(`${guideTable} thead th`, { fontSize: 11, color: colors.muted, fontWeight: 500 })
globalStyle(`${guideTable} tbody th`, { fontWeight: 600, whiteSpace: 'nowrap' })
globalStyle(`${guideTable} code`, {
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 11,
  whiteSpace: 'nowrap',
})
export const guideWarning = style({
  padding: '10px 12px',
  border: '1px solid #ead6a7',
  background: '#fff8e9',
  borderRadius: 7,
  fontSize: 12,
  lineHeight: 1.6,
})
globalStyle(`${guideWarning} p`, { margin: '5px 0' })
export const guideTimeline = style({
  border: `1px solid ${colors.border}`,
  borderRadius: 8,
  background: '#fff',
})
globalStyle(`${guideTimeline} > summary`, { padding: '11px 12px', fontWeight: 500 })
export const guideTimelineBody = style({ padding: '0 12px 12px' })
export const guideAssumptions = style({
  fontSize: 11,
  lineHeight: 1.65,
  color: colors.muted,
  paddingLeft: 18,
})
export const guideTableScroll = style({ overflowX: 'auto' })
export const activitySection = style({ background: '#fff' })
globalStyle(`${activitySection} > summary`, { fontWeight: 600 })
export const activityContent = style({ paddingTop: space.lg, display: 'grid', gap: space.lg })
export const activityStages = style({ display: 'grid', gap: space.md })
export const activityStage = style({
  padding: space.lg,
  border: `1px solid ${colors.border}`,
  borderRadius: 8,
  background: '#fafbfe',
})
globalStyle(`${activityStage} > header`, {
  display: 'flex',
  alignItems: 'center',
  flexWrap: 'wrap',
  gap: 10,
})
export const stageTag = style({
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 12,
  color: colors.accent,
  background: '#eae7fc',
  borderRadius: 5,
  padding: '4px 7px',
  minWidth: 36,
  textAlign: 'center',
})
export const activityStatus = style({
  fontSize: 11,
  color: colors.muted,
  selectors: { '&[data-status=interpreted]': { color: colors.text } },
})
export const activityBlocks = style({
  listStyle: 'none',
  display: 'grid',
  gridTemplateColumns: 'repeat(auto-fit, minmax(min(180px, 100%), 1fr))',
  gap: '8px 16px',
  margin: '16px 0 0 48px',
  padding: 0,
})
globalStyle(`${activityBlocks} li`, { padding: 0, fontSize: 12, color: '#515d70', lineHeight: 1.5 })

// Keep native disclosure/select behavior, with the same open-stroke chevrons
// used by the action icons instead of platform triangle markers.
const chevron = (path: string) =>
  `url("data:image/svg+xml,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#667180" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="${path}"/></svg>`)}")`
globalStyle('details > summary', {
  display: 'flex',
  alignItems: 'center',
  gap: 7,
  listStyle: 'none',
  cursor: 'pointer',
})
globalStyle('details > summary::-webkit-details-marker', { display: 'none' })
globalStyle('details > summary::marker', { content: '""' })
globalStyle('details > summary::before', {
  content: '""',
  display: 'inline-block',
  width: 14,
  height: 14,
  flexShrink: 0,
  backgroundImage: chevron('m9 18 6-6-6-6'),
  backgroundSize: 'contain',
  backgroundRepeat: 'no-repeat',
})
globalStyle('details[open] > summary::before', { transform: 'rotate(90deg)' })
globalStyle('details > summary:focus-visible', {
  outline: `2px solid ${colors.accent}`,
  outlineOffset: 3,
  borderRadius: 3,
})
globalStyle('select:not([multiple])', {
  appearance: 'none',
  backgroundImage: chevron('m6 9 6 6 6-6'),
  backgroundSize: '14px 14px',
  backgroundRepeat: 'no-repeat',
  backgroundPosition: 'right 8px center',
  paddingRight: 28,
})
globalStyle(`${valueCell} select:not([multiple])`, {
  padding: 0,
  backgroundPosition: 'center',
  backgroundSize: '12px 12px',
})
export const exampleName = style({
  display: 'flex',
  alignItems: 'baseline',
  flexWrap: 'wrap',
  gap: '5px 12px',
})
globalStyle(`${exampleName} code`, {
  fontFamily: 'IBM Plex Mono, monospace',
  fontSize: 11,
  fontWeight: 400,
  color: colors.muted,
})
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

export const modifiedTab = style({ color: '#a15c00', fontWeight: 500 })
export const diagramAction = style({
  display: 'inline-flex',
  alignItems: 'center',
  borderRadius: 6,
})
export const inspectionStatus = style({
  display: 'inline-flex',
  alignItems: 'center',
  justifyContent: 'center',
  width: 28,
  height: 28,
  color: colors.muted,
  selectors: { '&[data-following=true]': { color: colors.accent } },
})

export const boardConnectionActions = style({
  display: 'grid',
  gap: space.lg,
  paddingTop: space.lg,
  borderTop: `1px solid ${colors.border}`,
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

export const educationSection = style({ background: '#fff' })
export const cycleExplanation = style({ marginTop: space.lg, fontSize: 12 })
export const sectionCount = style({ fontSize: 11, fontWeight: 400, color: colors.muted })
export const memoryPanel = style({ background: '#fff' })
export const memoryBody = style({ display: 'grid', gap: space.lg, paddingTop: space.lg })
globalStyle(`${memoryBody} > ${registerGrid}`, { marginTop: 0 })
export const memoryTools = style({ display: 'flex', alignItems: 'center', gap: space.sm })
globalStyle(`${memoryTools} > label`, { flex: 1 })
globalStyle(`${memoryTools} input`, {
  width: '100%',
  height: 36,
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  background: '#fff',
  color: colors.text,
  font: 'inherit',
  fontSize: 12,
  padding: '8px 10px 8px 35px',
  minWidth: 0,
})
globalStyle(`${memoryTools} input:focus-visible`, {
  outline: `2px solid ${colors.accent}`,
  outlineOffset: 2,
})
export const memoryHint = style({
  display: 'inline-flex',
  alignItems: 'center',
  color: colors.muted,
  flexShrink: 0,
})
export const memoryEmpty = style({
  display: 'flex',
  alignItems: 'center',
  gap: space.lg,
  padding: '24px 16px',
  background: '#fafbfe',
  borderRadius: 7,
  color: colors.muted,
})
globalStyle(`${memoryEmpty} h4`, {
  fontSize: 13,
  fontWeight: 500,
  color: colors.text,
  margin: '0 0 4px',
})
globalStyle(`${memoryEmpty} p`, { fontSize: 12, lineHeight: 1.6, margin: 0 })
globalStyle(`${results} > details > summary::before`, { order: 2, marginLeft: 'auto' })
globalStyle(`${memoryPanel} > summary > span:first-child`, { flex: 1 })
globalStyle(`${activityStage} h4`, { fontSize: 13, fontWeight: 600, margin: '0 0 4px' })

globalStyle(`${latchCard} > p`, {
  overflowWrap: 'anywhere',
  fontSize: 11,
  lineHeight: 1.6,
  margin: '12px 0',
})
