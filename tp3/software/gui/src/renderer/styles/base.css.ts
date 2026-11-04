import { globalFontFace, globalStyle } from '@vanilla-extract/css'
import { colors } from '../ui-tokens'

globalStyle('*', { boxSizing: 'border-box' })
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
globalStyle('button:disabled', { opacity: 0.5, cursor: 'default' })
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
