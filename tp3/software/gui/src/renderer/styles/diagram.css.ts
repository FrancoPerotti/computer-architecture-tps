import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'

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
