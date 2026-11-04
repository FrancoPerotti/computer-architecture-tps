import { globalStyle, style } from '@vanilla-extract/css'
import { colors } from '../ui-tokens'

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

export const modifiedTab = style({ color: '#a15c00', fontWeight: 500 })
