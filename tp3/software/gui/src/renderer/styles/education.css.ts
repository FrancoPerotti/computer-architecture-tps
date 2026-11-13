import { globalStyle, style } from '@vanilla-extract/css'
import { colors, space } from '../ui-tokens'

export const exampleAbout = style({
  padding: '10px 16px',
  background: '#f4f3ff',
  borderBottom: `1px solid ${colors.border}`,
  flexShrink: 0,
  maxHeight: '35%',
  overflow: 'auto',
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

export const educationSection = style({ background: '#fff' })
export const cycleExplanation = style({ marginTop: space.lg, fontSize: 12 })
globalStyle(`${activityStage} h4`, { fontSize: 13, fontWeight: 600, margin: '0 0 4px' })
