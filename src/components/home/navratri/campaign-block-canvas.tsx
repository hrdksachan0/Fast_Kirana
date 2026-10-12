'use client'

import Image from 'next/image'
import Link from 'next/link'
import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from 'react'
import { Pause, Play } from 'lucide-react'
import type { Product } from '@/types'
import type { CampaignBlock, CampaignConfig } from '@/lib/campaign-config'
import { campaignBlockItems, campaignMotionInterval } from '@/lib/campaign-blocks'
import { ProductCard } from '@/components/product/product-card'
import {
  destinationHref,
  filterDemoProducts,
  filterNavratriProducts,
  navratriAsset,
  navratriPrice,
  resolveCampaignPromotions,
} from './data'
import { useRotation } from './use-rotation'
import styles from './campaign-blocks.module.css'

function Artwork({ image }: { image: string }) {
  return (
    <span className={styles.artFrame} aria-hidden="true">
      <Image
        src={navratriAsset(image)}
        alt=""
        width={400}
        height={240}
        unoptimized
        className={styles.art}
      />
    </span>
  )
}

function Motion({
  block,
  paused,
  fadeMs,
  children,
}: {
  block: CampaignBlock
  paused: boolean
  fadeMs: number
  children: ReactNode
}) {
  const [running, setRunning] = useState(false)
  useEffect(() => {
    const media = window.matchMedia('(prefers-reduced-motion: reduce)')
    const sync = () =>
      setRunning(!paused && !media.matches && document.visibilityState === 'visible')
    sync()
    media.addEventListener('change', sync)
    document.addEventListener('visibilitychange', sync)
    return () => {
      media.removeEventListener('change', sync)
      document.removeEventListener('visibilitychange', sync)
    }
  }, [paused])
  return (
    <div
      className={styles.block}
      data-campaign-block={block.id}
      data-block-type={block.type}
      data-presentation={block.presentation}
      data-motion={block.motion.preset}
      data-running={running}
      style={
        {
          '--block-loop':
            block.motion.speed === 'slow' ? '6s' : block.motion.speed === 'fast' ? '2.6s' : '4s',
          '--block-fade': `${block.motion.preset === 'none' || !running ? 0 : Math.min(1200, fadeMs * (block.motion.speed === 'slow' ? 1.5 : block.motion.speed === 'fast' ? 0.65 : 1))}ms`,
        } as CSSProperties
      }
    >
      {children}
    </div>
  )
}

function Copy({ block, fallback }: { block: CampaignBlock; fallback?: string }) {
  return (
    <>
      {(block.title || fallback) && <h3 className={styles.heading}>{block.title || fallback}</h3>}
      {block.body && <p className={styles.body}>{block.body}</p>}
    </>
  )
}

function Banner({
  block,
  data,
  paused,
}: {
  block: CampaignBlock
  data: CampaignConfig
  paused: boolean
}) {
  const headers = campaignBlockItems(data.headers, block.itemIds)
  const index = useRotation(
    headers.length,
    campaignMotionInterval(data.timings.headerMs, block.motion),
    paused
  )
  const root = useRef<HTMLDivElement>(null)
  const [height, setHeight] = useState(200)
  useEffect(() => {
    const element = root.current
    if (!element) return
    const copies = Array.from(element.querySelectorAll<HTMLElement>('[data-banner-copy]'))
    const measure = () =>
      setHeight(
        Math.max(
          element.clientWidth >= 650 ? 250 : 200,
          ...copies.map((copy) => copy.scrollHeight + 48)
        )
      )
    const observer = new ResizeObserver(measure)
    observer.observe(element)
    copies.forEach((copy) => observer.observe(copy))
    measure()
    return () => observer.disconnect()
  }, [headers, block.title, block.body])
  return (
    <div className={styles.banner} ref={root} style={{ minHeight: height }} aria-live="off">
      {headers.map((header, i) => (
        <div
          key={header.id}
          className={styles.slide}
          data-active={i === index}
          data-has-art={Boolean(block.image || header.image)}
          inert={i !== index}
          aria-hidden={i !== index}
        >
          <div className={styles.bannerCopy} data-banner-copy>
            {header.eyebrow && <p>{header.eyebrow}</p>}
            <h2>{block.title || header.title}</h2>
            <p>{block.body || header.subtitle}</p>
          </div>
          {(block.image || header.image) && <Artwork image={(block.image || header.image)!} />}
        </div>
      ))}
    </div>
  )
}

function Spotlight({
  block,
  data,
  catalogue,
  paused,
}: {
  block: CampaignBlock
  data: CampaignConfig
  catalogue: Product[]
  paused: boolean
}) {
  const resolved = resolveCampaignPromotions(data, catalogue)
  const products = campaignBlockItems(resolved.products, block.itemIds)
  const index = useRotation(
    products.length,
    campaignMotionInterval(data.timings.productMs, block.motion),
    paused
  )
  return (
    <>
      <Copy block={block} fallback={data.labels.specialsHeading} />
      <div className={styles.spotlight} aria-live="off">
        {!products.length && <p className={styles.body}>{data.labels.emptyText}</p>}
        {products.map((product, i) => (
          <Link
            key={product.id}
            href={destinationHref(product.destinationId, data)}
            prefetch={false}
            className={styles.productSlide}
            data-active={i === index}
            inert={i !== index}
            aria-hidden={i !== index}
            tabIndex={i === index ? 0 : -1}
            aria-label={`Explore ${product.name}${!product.productId ? ' — demo price' : ''}`}
          >
            <div>
              <span className={styles.price}>
                {product.originalPrice > product.price && (
                  <del>{navratriPrice(product.originalPrice)}</del>
                )}
                <strong>{navratriPrice(product.price)}</strong>
              </span>
              <span className={styles.productName}>{product.name}</span>
              {!product.productId && <small>{data.labels.demoLabel}</small>}
            </div>
            <Artwork image={product.image} />
          </Link>
        ))}
      </div>
    </>
  )
}

function Collection({
  block,
  data,
  catalogue,
  loading,
}: {
  block: CampaignBlock
  data: CampaignConfig
  catalogue: Product[]
  loading: boolean
}) {
  const tab = data.tabs.find((tab) => tab.id === block.tabId)!
  const matches = filterNavratriProducts(catalogue, tab.keywords, data, tab.productIds).slice(0, 12)
  const demos = catalogue.length || loading || !data.demo ? [] : filterDemoProducts(tab, data)
  return (
    <>
      <Copy block={block} fallback={tab.label} />
      {loading ? (
        <p className={styles.body} role="status">
          {data.labels.loadingText}
        </p>
      ) : matches.length ? (
        <div className={styles.collection}>
          {matches.map((product) => (
            <ProductCard
              key={product.id}
              product={product}
              renderArtwork={(artwork) => (
                <span className={`${styles.artFrame} ${styles.liveArtwork}`}>
                  <span className={styles.art} data-campaign-product-art>
                    {artwork}
                  </span>
                </span>
              )}
            />
          ))}
        </div>
      ) : demos.length ? (
        <>
          <p className={styles.caption}>{data.labels.resultsDemoLabel}</p>
          <div className={styles.collection}>
            {demos.map((product) => (
              <Link
                className={styles.demo}
                key={product.id}
                href={destinationHref(product.destinationId, data)}
                prefetch={false}
              >
                <Artwork image={product.image} />
                <span>{product.name}</span>
                <strong>
                  {navratriPrice(product.price)} <small>Demo</small>
                </strong>
                <small>Search catalogue</small>
              </Link>
            ))}
          </div>
        </>
      ) : (
        <p className={styles.body}>{data.labels.emptyText}</p>
      )}
    </>
  )
}

export function CampaignBlockCanvas({
  data,
  catalogue,
  loading,
  paused,
  onPause,
}: {
  data: CampaignConfig
  catalogue: Product[]
  loading: boolean
  paused: boolean
  onPause: () => void
}) {
  const [focused, setFocused] = useState(false)
  const stop = paused || focused || !data.autoplay
  return (
    <div
      className={styles.canvas}
      data-testid="campaign-block-canvas"
      onFocusCapture={(event) => setFocused(!event.target.closest('[data-playback-controls]'))}
      onBlurCapture={(event) => {
        if (!event.currentTarget.contains(event.relatedTarget)) setFocused(false)
      }}
    >
      <div className={styles.toolbar} data-playback-controls>
        <span>{data.labels.sectionLabel}</span>
        <button
          type="button"
          onClick={onPause}
          aria-label={paused ? 'Play campaign animations' : 'Pause campaign animations'}
          aria-pressed={paused}
        >
          {paused ? <Play size={14} aria-hidden="true" /> : <Pause size={14} aria-hidden="true" />}{' '}
          {paused ? 'Play' : 'Pause'}
        </button>
      </div>
      {data.blocks
        .filter((block) => block.enabled)
        .map((block) => (
          <Motion key={block.id} block={block} paused={stop} fadeMs={data.timings.crossfadeMs}>
            {block.type === 'banner' ? (
              <Banner block={block} data={data} paused={stop} />
            ) : block.type === 'spotlight' ? (
              <Spotlight block={block} data={data} catalogue={catalogue} paused={stop} />
            ) : block.type === 'collection' ? (
              <Collection block={block} data={data} catalogue={catalogue} loading={loading} />
            ) : block.type === 'categories' ? (
              <>
                <Copy block={block} />
                <div
                  className={styles.categories}
                  style={
                    {
                      '--category-small-columns': Math.min(
                        2,
                        block.itemIds.length || data.categories.length
                      ),
                      '--category-large-columns': Math.min(
                        4,
                        block.itemIds.length || data.categories.length
                      ),
                    } as CSSProperties
                  }
                >
                  {campaignBlockItems(data.categories, block.itemIds).map((category) => (
                    <Link
                      key={category.id}
                      prefetch={false}
                      href={destinationHref(category.destinationId, data)}
                      className={styles.category}
                      aria-label={`Shop ${category.label}`}
                    >
                      <h3>{category.label}</h3>
                      <Artwork image={category.image} />
                    </Link>
                  ))}
                </div>
              </>
            ) : (
              (() => {
                const content = (
                  <>
                    {block.type === 'image' && block.image && <Artwork image={block.image} />}
                    <Copy block={block} />
                    {block.destinationId && (
                      <span className={styles.browse}>Browse collection</span>
                    )}
                  </>
                )
                return block.destinationId ? (
                  <Link
                    href={destinationHref(block.destinationId, data)}
                    prefetch={false}
                    className={styles.message}
                  >
                    {content}
                  </Link>
                ) : (
                  <div className={styles.message}>{content}</div>
                )
              })()
            )}
          </Motion>
        ))}
    </div>
  )
}
