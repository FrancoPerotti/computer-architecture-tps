import * as styles from './theme.css'

export function Brand() {
  return (
    <span className={styles.brand} aria-label="viewrv">
      <span>v</span>
      <span className={styles.brandSeparator} aria-hidden="true" />
      <span>rv</span>
    </span>
  )
}
