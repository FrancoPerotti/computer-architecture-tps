import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'
import { iconButton } from './controls.css'

export const error = style({
  padding: '8px 12px',
  background: '#fff0ec',
  color: '#8c2929',
  display: 'flex',
  justifyContent: 'space-between',
  gap: 10,
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
export const preferenceCard = style({
  padding: space.lg,
  minHeight: 66,
  border: `1px solid ${colors.border}`,
  borderRadius: 9,
  background: '#fff',
})
globalStyle(`${preferenceCard} > span`, { display: 'flex', alignItems: 'center', gap: 10 })

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

export const boardConnectionActions = style({
  display: 'grid',
  gap: space.lg,
  paddingTop: space.lg,
  borderTop: `1px solid ${colors.border}`,
})
