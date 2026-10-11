'use client'

import Image from 'next/image'
import Link from 'next/link'
import { useEffect, useId, useRef, useState, type CSSProperties, type KeyboardEvent } from 'react'
import { Pause, Play } from 'lucide-react'
import type { Product } from '@/types'
import { ProductCard } from '@/components/product/product-card'
import {
  destinationHref,
  filterDemoProducts,
  filterNavratriProducts,
  navratriAsset,
  navratriData,
  navratriPrice,
  resolveCampaignPromotions,
  type NavratriData,
} from './data'
import { useRotation } from './use-rotation'
import { usePromotionProducts } from './use-promotion-products'
import { campaignHeaderSecondary } from '@/lib/campaign-appearance'
import styles from './navratri.module.css'

function RotatingHeader({ data, paused }: { data: NavratriData; paused: boolean }) {
  const index = useRotation(data.headers.length, data.timings.headerMs, paused)
  const container = useRef<HTMLDivElement>(null)
  const [height, setHeight] = useState<number>()
  useEffect(() => {
    const element = container.current
    if (!element) return
    const measure = () => {
      const base =
        data.layout === 'banner'
          ? element.clientWidth >= 700
            ? 216
            : 176
          : element.clientWidth >= 700
            ? 132
            : 100
      const copies = Array.from(element.querySelectorAll<HTMLElement>('[data-header-copy]'))
      setHeight(
        Math.max(base, ...copies.map((copy) => Math.ceil(copy.getBoundingClientRect().height) + 24))
      )
    }
    const observer = new ResizeObserver(measure)
    observer.observe(element)
    element
      .querySelectorAll<HTMLElement>('[data-header-copy]')
      .forEach((copy) => observer.observe(copy))
    measure()
    return () => observer.disconnect()
  }, [data.headers, data.layout])
  return (
    <div
      ref={container}
      style={height ? { height } : undefined}
      className={styles.header}
      data-testid="navratri-header"
      aria-live="off"
    >
      {data.headers.map((slide, i) => (
        <div
          key={slide.id}
          className={styles.headerSlide}
          data-kind={slide.kind}
          data-active={i === index}
          aria-hidden={i !== index}
          inert={i !== index}
        >
          {slide.image && (
            <Image
              src={navratriAsset(slide.image)}
              alt=""
              width={180}
              height={90}
              unoptimized
              className={styles.headerArt}
              loading="eager"
            />
          )}
          <div className={styles.headerCopy} data-header-copy>
            {slide.eyebrow && <p>{slide.eyebrow}</p>}
            <h2>{slide.title}</h2>
            {slide.subtitle && <p>{slide.subtitle}</p>}
          </div>
        </div>
      ))}
    </div>
  )
}

function RotatingProduct({ data, paused }: { data: NavratriData; paused: boolean }) {
  const index = useRotation(data.products.length, data.timings.productMs, paused)
  useEffect(() => {
    if (!data.products.length) return
    const next = data.products[(index + 1) % data.products.length]
    const image = new window.Image()
    image.src = navratriAsset(next.image)
    void image.decode().catch(() => {})
  }, [data.products, index])
  return (
    <article className={styles.special} data-testid="navratri-special">
      <h3>{data.labels.specialsHeading}</h3>
      <div className={styles.productStage} aria-live="off">
        {!data.products.length && <p className={styles.empty}>{data.labels.emptyText}</p>}
        {data.products.map((product, i) => (
          <Link
            key={product.id}
            href={destinationHref(product.destinationId, data)}
            prefetch={false}
            className={styles.productSlide}
            data-active={i === index}
            aria-hidden={i !== index}
            inert={i !== index}
            tabIndex={i === index ? 0 : -1}
            aria-label={`Explore ${product.name}${data.demo ? ' — demo price' : ''}`}
          >
            <span className={styles.pricePill}>
              <del>{navratriPrice(product.originalPrice)}</del>
              <strong>{navratriPrice(product.price)}</strong>
            </span>
            <Image
              src={navratriAsset(product.image)}
              alt=""
              width={150}
              height={150}
              unoptimized
              loading="eager"
              className={styles.specialImage}
            />
            <span className={styles.productName}>{product.name}</span>
          </Link>
        ))}
      </div>
      {data.demo && <span className={styles.demoPrice}>{data.labels.demoLabel}</span>}
    </article>
  )
}

export function NavratriSection({
  products = [],
  data = navratriData,
  loading = false,
  storeId,
  resolveLinkedProducts = true,
}: {
  products?: Product[]
  data?: NavratriData
  loading?: boolean
  storeId?: string | null
  resolveLinkedProducts?: boolean
}) {
  const [paused, setPaused] = useState(false)
  const [focused, setFocused] = useState(false)
  const [selected, setSelected] = useState(0)
  const id = useId()
  const currentTab = Math.min(selected, data.tabs.length - 1)
  const tab = data.tabs[currentTab]
  const promotionCatalogue = usePromotionProducts(
    data,
    products,
    storeId,
    loading,
    resolveLinkedProducts
  )
  const promotion = resolveCampaignPromotions(data, promotionCatalogue)
  const filtered = filterNavratriProducts(promotionCatalogue, tab.keywords, data, (tab as any).productIds).slice(0, 12)
  const demos = products.length || loading || !data.demo ? [] : filterDemoProducts(tab, data)
  const categoryCards = data.categories.map((category) => (
    <Link
      key={category.id}
      href={destinationHref(category.destinationId, data)}
      prefetch={false}
      className={styles.category}
      aria-label={`Shop ${category.label}`}
    >
      <h3>{category.label}</h3>
      <Image
        src={navratriAsset(category.image)}
        alt=""
        width={140}
        height={90}
        unoptimized
        className={styles.categoryImage}
        loading="eager"
      />
    </Link>
  ))
  const productSpotlight = (
    <RotatingProduct data={promotion} paused={paused || focused || !data.autoplay} />
  )
  const keyboardTab = (event: KeyboardEvent<HTMLButtonElement>, current: number) => {
    let next = current
    if (event.key === 'ArrowRight') next = (current + 1) % data.tabs.length
    else if (event.key === 'ArrowLeft') next = (current - 1 + data.tabs.length) % data.tabs.length
    else if (event.key === 'Home') next = 0
    else if (event.key === 'End') next = data.tabs.length - 1
    else return
    event.preventDefault()
    setSelected(next)
    document.getElementById(`${id}-tab-${next}`)?.focus()
  }
  return (
    <section
      className={styles.section}
      aria-label={data.labels.sectionLabel}
      data-testid="navratri-section"
      data-layout={data.layout}
      style={
        {
          '--navratri-fade': `${data.timings.crossfadeMs}ms`,
          '--festival-orange': data.appearance.background,
          '--festival-cream': data.appearance.card,
          '--festival-brown': data.appearance.text,
          '--festival-small': data.appearance.smallText,
          '--festival-header': data.appearance.headerText,
          '--festival-header-secondary': campaignHeaderSecondary(data.appearance),
          '--festival-outline': data.appearance.headerOutline,
          '--festival-underline': data.appearance.underline,
          '--festival-tab': data.appearance.tabSurface,
          '--campaign-tabs': data.tabs.length,
        } as CSSProperties
      }
    >
      <div className={styles.festival}>
        {data.decorationImage && (
          <Image
            src={navratriAsset(data.decorationImage)}
            alt=""
            width={900}
            height={32}
            unoptimized
            className={styles.lights}
            loading="eager"
          />
        )}
        <RotatingHeader data={data} paused={paused || focused || !data.autoplay} />
        <div
          className={data.layout === 'classic' ? styles.cards : styles.variantCards}
          onFocusCapture={() => setFocused(true)}
          onBlurCapture={(event) => {
            if (!event.currentTarget.contains(event.relatedTarget)) setFocused(false)
          }}
        >
          {data.layout === 'classic' ? (
            <>
              {productSpotlight}
              {categoryCards}
            </>
          ) : (
            <>
              {(data.layout === 'banner' || data.layout === 'deals') && productSpotlight}
              <div className={styles.categoryDeck}>{categoryCards}</div>
              {(data.layout === 'split' || data.layout === 'grid') && productSpotlight}
            </>
          )}
        </div>
        <div className={styles.festivalFooter}>
          <button
            type="button"
            className={styles.pause}
            onClick={() => setPaused((value) => !value)}
            aria-label={paused ? 'Play campaign animations' : 'Pause campaign animations'}
            aria-pressed={paused}
          >
            {paused ? (
              <Play size={13} aria-hidden="true" />
            ) : (
              <Pause size={13} aria-hidden="true" />
            )}
            <span>{paused ? 'Play' : 'Pause'}</span>
          </button>
          <span className={styles.curvedTab}>{data.labels.curvedTabLabel}</span>
        </div>
      </div>
      <div
        className={styles.tabs}
        role="tablist"
        aria-label={`${data.labels.sectionLabel} collections`}
      >
        {data.tabs.map((item, i) => (
          <button
            key={item.id}
            type="button"
            role="tab"
            id={`${id}-tab-${i}`}
            aria-controls={`${id}-panel`}
            aria-selected={i === currentTab}
            tabIndex={i === currentTab ? 0 : -1}
            className={styles.tab}
            onClick={() => setSelected(i)}
            onKeyDown={(event) => keyboardTab(event, i)}
          >
            <span className={styles.tabArt}>
              <Image src={navratriAsset(item.image)} alt="" width={64} height={64} unoptimized />
            </span>
            <span>{item.label}</span>
          </button>
        ))}
      </div>
      <div
        id={`${id}-panel`}
        role="tabpanel"
        aria-labelledby={`${id}-tab-${currentTab}`}
        tabIndex={0}
        className={styles.results}
      >
        <div className={styles.resultsHeading}>
          <h3>{tab.label}</h3>
          {products.length === 0 && !loading && data.demo && (
            <span>{data.labels.resultsDemoLabel}</span>
          )}
        </div>
        {loading ? (
          <p className={styles.empty} role="status">
            {data.labels.loadingText}
          </p>
        ) : filtered.length > 0 ? (
          <div className={styles.productGrid}>
            {filtered.map((product) => (
              <ProductCard key={product.id} product={product} />
            ))}
          </div>
        ) : demos.length > 0 ? (
          <div className={styles.productGrid}>
            {demos.map((product) => (
              <Link
                key={product.id}
                href={destinationHref(product.destinationId, data)}
                prefetch={false}
                className={styles.demoProduct}
              >
                <Image
                  src={navratriAsset(product.image)}
                  alt=""
                  width={130}
                  height={130}
                  unoptimized
                />
                <span>{product.name}</span>
                <strong>
                  {navratriPrice(product.price)} <small>Demo</small>
                </strong>
                <span className={styles.browse}>Search catalogue</span>
              </Link>
            ))}
          </div>
        ) : (
          <p className={styles.empty}>{data.labels.emptyText}</p>
        )}
      </div>
    </section>
  )
}
