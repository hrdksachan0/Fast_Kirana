'use client'

import { useState } from 'react'
import { Search } from 'lucide-react'
import { navratriData, type NavratriData } from './data'
import { useRotation } from './use-rotation'
import styles from './navratri.module.css'

export function NavratriSearch({
  onSearch,
  data = navratriData,
}: {
  onSearch: () => void
  data?: NavratriData
}) {
  const [paused, setPaused] = useState(false)
  const index = useRotation(
    data.searchSuggestions.length,
    data.timings.searchMs,
    paused || !data.autoplay
  )
  return (
    <button
      type="button"
      className={styles.search}
      onClick={onSearch}
      aria-label="Search FastMinute products"
      onMouseEnter={() => setPaused(true)}
      onMouseLeave={() => setPaused(false)}
      onFocus={() => setPaused(true)}
      onBlur={() => setPaused(false)}
    >
      <Search size={18} aria-hidden="true" />
      <span aria-hidden="true">{data.searchPrefix}</span>
      <span className={styles.suggestions} aria-hidden="true">
        {data.searchSuggestions.map((suggestion, slide) => (
          <span key={suggestion} className={styles.suggestion} data-active={slide === index}>
            {suggestion}
          </span>
        ))}
      </span>
    </button>
  )
}
