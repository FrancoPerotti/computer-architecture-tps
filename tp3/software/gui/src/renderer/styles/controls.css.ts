import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'

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
export const errorText = style({ color: colors.error })
export const successText = style({ color: colors.success })
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
globalStyle(`${menuTrigger}:hover:not(:disabled)`, { background: '#e4e7ee' })
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
globalStyle(`${iconButton} > svg`, { display: 'block', flexShrink: 0 })
