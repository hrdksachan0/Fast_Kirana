'use client'

import { useEffect, useRef, useState, type CSSProperties } from 'react'
import { ArrowLeft, ArrowRight, Check, ChevronDown, Leaf, Minus, Pause, Play, Plus, Search, ShoppingBag, SlidersHorizontal, Sparkles, X } from 'lucide-react'
import { showcaseThemes, type ShowcaseProduct, type ShowcaseTheme } from './showcase-data'
import styles from './campaign-studio.module.css'

const money = (amount: number) => `₹${amount}`

export function CampaignStudio() {
  const [selected, setSelected] = useState('fresh')
  const [paused, setPaused] = useState(false)
  const [titles, setTitles] = useState<Record<string, string>>({})
  const theme = showcaseThemes.find((item) => item.id === selected)!
  return (
    <div className={styles.studio}>
      <header className={styles.studioHeader}>
        <a href="/" className={styles.wordmark}>FastMinute<span> / design studio</span></a>
        <span className={styles.previewLabel}><span /> Interactive concept</span>
      </header>
      <div className={styles.workspace}>
        <aside className={styles.sidebar}>
          <p className={styles.eyebrow}>THE CAMPAIGN COLLECTION / 01—07</p>
          <h1>One store.<br />So many stories.</h1>
          <p className={styles.intro}>Connected worlds for the things people love to shop. Choose a story. Try the experience.</p>
          <nav className={styles.themes} aria-label="Campaign designs">
            {showcaseThemes.map((item, index) => (
              <button key={item.id} type="button" onClick={() => setSelected(item.id)} aria-pressed={selected === item.id} style={{ '--swatch': item.accent } as CSSProperties}>
                <span className={styles.themeNumber}>0{index + 1}</span><span className={styles.swatch} /><span>{item.name}</span>{selected === item.id ? <ArrowRight size={17} /> : null}
              </button>
            ))}
          </nav>
          <div className={styles.controls}>
            <label htmlFor="campaign-headline">MAKE IT YOURS <SlidersHorizontal size={13} /></label>
            <input id="campaign-headline" aria-label="Campaign headline" maxLength={70} value={titles[selected] ?? theme.title.replace('\n', ' ')} onChange={(event) => setTitles({ ...titles, [selected]: event.target.value })} />
            <button type="button" onClick={() => setPaused(!paused)} aria-pressed={paused}>{paused ? <Play size={15} /> : <Pause size={15} />}{paused ? 'Play ambient motion' : 'Pause ambient motion'}</button>
          </div>
          <p className={styles.note}>Sample products and prices. Preview baskets stay separate from your shopping cart.</p>
        </aside>
        <div className={styles.stage} style={{ '--stage-tint': theme.soft } as CSSProperties}>
          <div className={styles.stageCaption}><span>0{showcaseThemes.indexOf(theme) + 1} / {theme.name}</span><span>SCROLL TO EXPLORE ↓</span></div>
          <div className={styles.phone}>
            <ShoppingPreview key={selected} theme={theme} title={titles[selected] ?? theme.title} paused={paused} />
          </div>
          <p className={styles.stageFoot}><Check size={14} /> Connected canvas <span>·</span> Working filters <span>·</span> Live basket preview</p>
        </div>
      </div>
    </div>
  )
}

function ShoppingPreview({ theme, title, paused }: { theme: ShowcaseTheme; title: string; paused: boolean }) {
  const [category, setCategory] = useState('All')
  const [query, setQuery] = useState('')
  const [cart, setCart] = useState<Record<string, number>>({})
  const [detail, setDetail] = useState<ShowcaseProduct | null>(null)
  const [cartOpen, setCartOpen] = useState(false)
  const [inView, setInView] = useState(true)
  const hero = useRef<HTMLDivElement>(null)
  const scroller = useRef<HTMLDivElement>(null)
  const shelf = useRef<HTMLElement>(null)
  const dialog = useRef<HTMLDialogElement>(null)
  const dialogTrigger = useRef<HTMLElement | null>(null)
  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => setInView(entry.isIntersecting), { root: scroller.current })
    if (hero.current) observer.observe(hero.current)
    return () => observer.disconnect()
  }, [])
  useEffect(() => {
    if (detail || cartOpen) {
      dialogTrigger.current = document.activeElement as HTMLElement | null
      dialog.current?.showModal()
    } else if (dialog.current?.open) {
      dialog.current.close()
      dialogTrigger.current?.focus()
    }
  }, [detail, cartOpen])
  const totalItems = Object.values(cart).reduce((a, b) => a + b, 0)
  const total = theme.products.reduce((sum, product) => sum + product.price * (cart[product.id] ?? 0), 0)
  const visible = theme.products.filter((product) => (category === 'All' || product.category === category) && `${product.name} ${product.category}`.toLowerCase().includes(query.toLowerCase()))
  const update = (product: ShowcaseProduct, delta: number) => setCart((current) => ({ ...current, [product.id]: Math.max(0, Math.min(20, (current[product.id] ?? 0) + delta)) }))
  const close = () => { setDetail(null); setCartOpen(false) }
  const chooseCategory = (name: string) => {
    setCategory(name)
    shelf.current?.scrollIntoView({ block: 'nearest', behavior: 'instant' })
  }
  const quantity = (product: ShowcaseProduct) => (
    <div className={styles.quantity}>
      {cart[product.id] ? <><button type="button" aria-label={`Remove one ${product.name}`} onClick={() => update(product, -1)}><Minus size={14} /></button><span aria-label={`${cart[product.id]} in basket`}>{cart[product.id]}</span><button type="button" disabled={cart[product.id] >= 20} aria-label={`Add one ${product.name}`} onClick={() => update(product, 1)}><Plus size={14} /></button></> : <button type="button" className={styles.add} onClick={() => update(product, 1)} aria-label={`Add ${product.name}`}>ADD <Plus size={13} /></button>}
    </div>
  )
  return (
    <div className={styles.shopping} data-layout={theme.layout} data-paused={paused || !inView} style={{ '--accent': theme.accent, '--ink': theme.ink, '--canvas': theme.background, '--soft': theme.soft } as CSSProperties}>
      <div className={styles.scrollArea} ref={scroller}>
        <div className={styles.delivery}><div><small>YOUR NEIGHBOURHOOD STORE</small><strong>Home · Ghatampur <ChevronDown size={14} /></strong></div><span className={styles.avatar}>Y</span></div>
        <label className={styles.search}><Search size={18} /><input aria-label="Search preview products" placeholder="Find your everyday favourites" value={query} onChange={(event) => setQuery(event.target.value)} />{query && <button aria-label="Clear search" onClick={() => setQuery('')}><X size={15} /></button>}</label>
        <div className={styles.connected}>
          <div ref={hero} className={styles.hero}>
            <div className={styles.heroCopy}><span className={styles.kicker}><Sparkles size={12} /> {theme.tag}</span><h2>{title}</h2><p>{theme.subtitle}</p><button type="button" onClick={() => chooseCategory('All')}>Explore the edit <ArrowRight size={14} /></button></div>
            <div className={styles.heroOrb} aria-hidden="true" /><img className={styles.heroArt} src={theme.hero} alt="" /><span className={styles.heroMark} aria-hidden="true">✳</span>
          </div>
          <div className={styles.sectionEyebrow}><span>THE {theme.id === 'snacks' ? 'MOOD' : 'COLLECTION'} EDIT</span><span>CURATED FOR YOU</span></div>
          <div className={styles.categoryTiles}>
            {theme.categories.map((item, index) => <button key={item.name} type="button" onClick={() => chooseCategory(item.name)} aria-label={`Shop ${item.name}`} className={styles.categoryTile}><span className={styles.tileCopy}><small>0{index + 1}</small><strong>{item.name}</strong><span>{item.caption}</span></span><img src={item.image} alt="" /><span className={styles.tileArrow}><ArrowRight size={15} /></span></button>)}
          </div>
          <section className={styles.shelf} ref={shelf} aria-label="Sample product collection">
            <div className={styles.shelfHeading}><div><span className={styles.eyebrow}>YOUR NEXT GOOD FIND</span><h3>{theme.shelf}</h3></div><Leaf size={22} strokeWidth={1.3} /></div>
            <div className={styles.filters} role="group" aria-label="Filter preview products">{['All', ...theme.categories.map((item) => item.name)].map((name) => <button key={name} type="button" aria-pressed={category === name} onClick={() => setCategory(name)}>{name}</button>)}</div>
            <div className={styles.products}>
              {visible.map((product) => <article key={product.id} className={styles.product}><button type="button" className={styles.productOpen} onClick={() => setDetail(product)} aria-label={`View ${product.name}`}><div className={styles.productArt}><img src={product.image} alt={product.name} /></div><h4>{product.name}</h4><p>{product.unit}</p></button><div className={styles.productBottom}><strong>{money(product.price)}</strong>{quantity(product)}</div></article>)}
            </div>
            {!visible.length && <div className={styles.empty}><Search size={24} /><h4>No matches in this edit</h4><p>Try another category or a shorter search.</p><button onClick={() => { setCategory('All'); setQuery('') }}>Show all products</button></div>}
          </section>
          <div className={styles.endnote}><span>✳</span><p>A little inspiration.<br /><strong>A basket full of possibilities.</strong></p></div>
        </div>
      </div>
      <div className={styles.basketArea}>
        {totalItems ? <button type="button" className={styles.basket} onClick={() => setCartOpen(true)}><ShoppingBag size={18} /><span><strong>{totalItems} {totalItems === 1 ? 'item' : 'items'} · {money(total)}</strong><small>In your preview basket</small></span><span>View basket <ArrowRight size={16} /></span></button> : <p className={styles.basketHint}><ShoppingBag size={15} /> Find something you love. Try adding it.</p>}
        <div role="status" className={styles.srOnly}>{totalItems} items in preview basket. Total {money(total)}.</div>
      </div>
      <dialog ref={dialog} className={styles.dialog} aria-labelledby="preview-dialog-title" onCancel={close} onClick={(event) => { if (event.target === event.currentTarget) close() }}>
        <div className={styles.dialogHeader}><h3 id="preview-dialog-title">{detail ? 'A closer look' : 'Your preview basket'}</h3><button type="button" onClick={close} aria-label="Close preview"><X size={20} /></button></div>
        {detail ? <div className={styles.detail}><img src={detail.image} alt={detail.name} /><h4>{detail.name}</h4><p>{detail.unit} · {detail.category}</p><div className={styles.productBottom}><strong>{money(detail.price)}</strong>{quantity(detail)}</div></div> : <div className={styles.cartLines}>{theme.products.filter((product) => cart[product.id]).map((product) => <div key={product.id} className={styles.cartLine}><img src={product.image} alt="" /><div><strong>{product.name}</strong><small>{product.unit} · {money(product.price)}</small></div>{quantity(product)}</div>)}{!totalItems && <p>Your preview basket is empty.</p>}<div className={styles.cartTotal}><span>Item total</span><strong>{money(total)}</strong></div></div>}
        <p className={styles.dialogNote}>Design preview · Illustrative prices · No order will be placed.</p><button type="button" className={styles.continue} onClick={close}><ArrowLeft size={15} /> Keep exploring</button>
      </dialog>
    </div>
  )
}
