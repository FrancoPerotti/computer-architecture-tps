import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'

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

export const globalState = style({
  background: '#fafbfe',
  border: `1px solid ${colors.border}`,
  borderRadius: 7,
  padding: space.lg,
})
globalStyle(`${globalState} > h2`, { fontSize: 14, fontWeight: 600, color: colors.text, margin: 0 })
globalStyle(`${globalState} > div`, { marginTop: space.lg, gridAutoRows: '1fr' })
globalStyle(`${valueCell} select:not([multiple])`, {
  padding: 0,
  backgroundPosition: 'center',
  backgroundSize: '12px 12px',
})
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

globalStyle(`${latchCard} > p`, {
  overflowWrap: 'anywhere',
  fontSize: 11,
  lineHeight: 1.6,
  margin: '12px 0',
})
