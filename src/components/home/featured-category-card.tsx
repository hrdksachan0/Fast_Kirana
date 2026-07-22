'use client';

import { useState, useMemo, useRef, useEffect } from 'react';
import { ChevronRight, Heart } from 'lucide-react';
import { useCart } from '@/hooks/use-cart';
import { DEFAULT_CAFE_MENU_SECTIONS, DEFAULT_RESTAURANT_MENU_SECTIONS } from '@/lib/constants';
import { useUIStore } from '@/stores/ui-store';

interface Category {
  id: string;
  name: string;
  emoji: string;
}

interface FeaturedCategoryCardProps {
  title: string;
  eyebrow: string;
  bannerEmojis: string[];
  theme?: 'cafe' | 'restaurant' | 'monsoon';
  categories: Category[];
  products: any[];
  onSeeAll?: () => void;
}

const getShortTitle = (tag: string, fullTitle: string) => {
  const customMapping: Record<string, string> = {
    'hot-beverage': 'Brews',
    'hot-bite': 'Snacks',
    'sandwiches': 'Sandwiches',
    'frankie-rolls': 'Rolls',
    'chinese': 'Chinese',
    'italian-pasta': 'Pasta',
    'bombay-bites': 'Bombay',
    'rice-dishes': 'Rice',
    'shakes': 'Shakes',
    'mocktails': 'Mocktails',
    'cold-coffee': 'Coffee',
    'south-indian': 'South Indian',
    'bakery': 'Bakery',
    'chilled': 'Cold Drinks',
    'pizza': 'Pizzas',
    'burgers': 'Burgers',
    'garlic-bread': 'Garlic Bread',
    'desserts': 'Desserts',
    'north-indian': 'North Indian',
    'biryani-rice': 'Biryani',
    'breakfast': 'Breakfast',
    'starter': 'Starters',
    'main-course': 'Main Course',
    'roti-naan-kulcha': 'Breads',
    'rice,-biryani': 'Biryani',
    'dal': 'Dals',
    'tandoori-nawab-nawab': 'Tandoori',
    'shake': 'Shakes',
    'soup': 'Soups',
    'burger': 'Burgers',
    'pasta': 'Pastas',
    'special-starters': 'Special Starters',
  };
  return customMapping[tag] || fullTitle;
};

export default function FeaturedCategoryCard({ 
  title,
  eyebrow,
  bannerEmojis,
  theme = 'cafe',
  categories,
  products,
  onSeeAll
}: FeaturedCategoryCardProps) {
  const { addItem, getItemQuantity, updateQuantity } = useCart();
  const settings = useUIStore((s) => s.settings) || {};

  const [liveProducts, setLiveProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [localWishlist, setLocalWishlist] = useState<Set<string>>(new Set());
  const [activeCategory, setActiveCategory] = useState<string | null>(null);
  const [transitionState, setTransitionState] = useState('');
  const [pendingCategory, setPendingCategory] = useState<string | null>(null);

  const catStripRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    let isMounted = true;
    const fetchProducts = async () => {
      setLoading(true);
      try {
        let url = '';
        if (theme === 'cafe') {
          url = '/api/products?category=cafe,ice-cream,beverages&limit=100';
        } else if (theme === 'restaurant') {
          url = '/api/products?category=restaurant&limit=100';
        } else {
          setLiveProducts(products || []);
          setLoading(false);
          return;
        }

        const res = await fetch(url);
        const data = await res.json();
        const items = data.products || data || [];
        
        if (isMounted) {
          setLiveProducts(items);
        }
      } catch (err) {
        console.error('Failed to fetch real products for ' + title, err);
        if (isMounted) {
          setLiveProducts(products || []);
        }
      } finally {
        if (isMounted) {
          setLoading(false);
        }
      }
    };

    fetchProducts();
    return () => {
      isMounted = false;
    };
  }, [theme, products, title]);

  // Helper matchers for database category structures
  const isTagMatch = (t1: string, t2: string) => {
    const a = t1.toLowerCase().trim();
    const b = t2.toLowerCase().trim();
    if (a === b) return true;
    if (a + 's' === b || b + 's' === a) return true;
    if (a + 'es' === b || b + 'es' === a) return true;
    if (a.endsWith('y') && a.slice(0, -1) + 'ies' === b) return true;
    if (b.endsWith('y') && b.slice(0, -1) + 'ies' === a) return true;
    return false;
  };

  const isProductInSection = (product: any, section: any) => {
    const slug = product.category?.slug || product.categorySlug || '';
    const tags = product.tags || [];
    
    return tags.some((t: string) => 
      isTagMatch(t, section.tag) || section.matchTags?.some((mt: string) => isTagMatch(t, mt))
    ) || isTagMatch(slug, section.tag);
  };

  // Parse menu sections dynamically from database store settings
  const parsedSections = useMemo(() => {
    if (theme !== 'cafe' && theme !== 'restaurant') return [];
    let sections = theme === 'cafe' ? DEFAULT_CAFE_MENU_SECTIONS : DEFAULT_RESTAURANT_MENU_SECTIONS;
    try {
      const raw = theme === 'restaurant'
        ? (settings.restaurant_menu_sections || settings.RESTAURANT_MENU_SECTIONS)
        : (settings.cafe_menu_sections || settings.CAFE_MENU_SECTIONS);
      if (raw) {
        const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
        if (Array.isArray(parsed) && parsed.length > 0) {
          sections = parsed;
        }
      }
    } catch (e) {
      console.error('Failed to parse dynamic sections in FeaturedCategoryCard', e);
    }
    // Filter out disabled sections
    return sections.filter((s: any) => !s.disabled);
  }, [theme, settings]);

  // Derive categories list dynamically from active database products
  const activeCategories = useMemo(() => {
    if (theme !== 'cafe' && theme !== 'restaurant') return [];
    
    const matched = parsedSections.map(sec => {
      const matchedProds = liveProducts.filter(p => isProductInSection(p, sec));
      return {
        sec,
        count: matchedProds.length
      };
    }).filter(item => item.count > 0);
    
    return matched.map(item => ({
      id: item.sec.tag,
      name: getShortTitle(item.sec.tag, item.sec.title),
      emoji: item.sec.emoji || '🍽️'
    }));
  }, [liveProducts, theme, parsedSections]);

  const finalCategories = useMemo(() => {
    if (activeCategories.length > 0) return activeCategories;
    return categories || [];
  }, [activeCategories, categories]);

  const finalActiveCategory = useMemo(() => {
    if (activeCategory && finalCategories.some(c => c.id === activeCategory)) {
      return activeCategory;
    }
    return finalCategories[0]?.id || null;
  }, [activeCategory, finalCategories]);

  const changeCategory = (catId: string) => {
    if (catId === finalActiveCategory) return;
    setPendingCategory(catId);
    setTransitionState('leaving');
  };

  useEffect(() => {
    if (transitionState === 'leaving' && pendingCategory !== null) {
      const timer = setTimeout(() => {
        setActiveCategory(pendingCategory);
        setTransitionState('entering');
        setPendingCategory(null);
      }, 250);
      return () => clearTimeout(timer);
    }
    if (transitionState === 'entering') {
      const timer = setTimeout(() => {
        setTransitionState('');
      }, 300);
      return () => clearTimeout(timer);
    }
  }, [transitionState, pendingCategory]);

  useEffect(() => {
    if (catStripRef.current && finalActiveCategory) {
      const activeEl = catStripRef.current.querySelector('.cat-pill.active') as HTMLElement;
      if (activeEl) {
        activeEl.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
      }
    }
  }, [finalActiveCategory]);

  const filteredProducts = useMemo(() => {
    const productsSource = liveProducts.length > 0 ? liveProducts : products;
    if (!finalActiveCategory) return [];

    if (activeCategories.length > 0) {
      const section = parsedSections.find(s => s.tag === finalActiveCategory);
      if (section) {
        return productsSource.filter(p => isProductInSection(p, section));
      }
    }
    // Fallback to static category matching
    return productsSource.filter(p => p.category === finalActiveCategory);
  }, [liveProducts, products, finalActiveCategory, activeCategories, parsedSections]);

  const isLiked = (id: string) => {
    return localWishlist.has(id);
  };

  const handleToggleWishlist = (id: string) => {
    setLocalWishlist(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const getProductQty = (p: any) => {
    return getItemQuantity(p.id);
  };

  const handleAddClick = (p: any) => {
    addItem({
      id: p.id,
      name: p.name,
      slug: p.slug || p.id,
      imageUrl: p.imageUrl || null,
      mrp: p.mrp || p.price,
      price: p.price,
      discount: p.discount || 0,
      unit: p.unit || p.packSize || '1 unit',
      stock: p.stock || p.stockLeft || 10,
      isAvailable: p.isAvailable ?? true,
      tags: p.tags || [],
      category: p.categoryObj || p.category || null
    });
  };

  const handleRemoveClick = (p: any) => {
    const currentQty = getItemQuantity(p.id);
    if (currentQty > 1) {
      updateQuantity(p.id, p.name, currentQty - 1);
    } else {
      updateQuantity(p.id, p.name, 0);
    }
  };

  return (
    <div className={`main-card theme-${theme}`}>
      {/* Sky-Blue / Orange / Green Header Zone */}
      <div className={`hero-zone theme-${theme}`}>
        <div className="banner-content">
          <div className="banner-left">
            <p className="banner-eyebrow">{eyebrow}</p>
            <h2 className="banner-heading">{title}</h2>
          </div>
          <div className="banner-right">
            {bannerEmojis.map((emoji, index) => (
              <span key={index} className={`banner-art-${(index % 4) + 1}`}>{emoji}</span>
            ))}
          </div>
        </div>

        {/* Category Vertical Slider */}
        <div className="cat-strip" ref={catStripRef}>
          {finalCategories.map((cat) => (
            <button
              key={cat.id}
              className={`cat-pill ${finalActiveCategory === cat.id ? 'active' : ''}`}
              onClick={() => changeCategory(cat.id)}
            >
              <div className="cat-circle">{cat.emoji}</div>
              <span className="cat-name">{cat.name}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Products Section */}
      <section className="prod-section">
        <div className={`prod-scroll ${transitionState === 'leaving' ? 'transitioning' : ''} ${transitionState === 'entering' ? 'entering' : ''}`}>
          {loading ? (
            Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="snap-start w-[140px] sm:w-[170px] shrink-0 animate-pulse bg-zinc-200 dark:bg-zinc-800 rounded-xl h-[260px]" />
            ))
          ) : filteredProducts.length === 0 ? (
            <div style={{ width: '100%', textAlign: 'center', padding: '40px 20px', color: '#64748b' }}>
              <p style={{ fontSize: '2.5rem', marginBottom: '8px' }}>🔍</p>
              <h4 style={{ fontWeight: '700' }}>No products found</h4>
              <p style={{ fontSize: '0.75rem' }}>Try changing categories</p>
            </div>
          ) : (
            filteredProducts.map((p) => {
              const qty = getProductQty(p);
              const isProductLiked = isLiked(p.id);
              const mrpVal = p.mrp || p.originalPrice || p.price;
              const discountVal = mrpVal - p.price;
              const hasDiscount = mrpVal > p.price;
              const categoryLabel = p.categoryObj?.name || (typeof p.category === 'object' ? p.category?.name : p.category) || 'Food';

              return (
                <div key={p.id} className="pcard">
                  {/* Image Area */}
                  <div className="pcard-img" style={{ background: p.bgColor || '#f8fafc' }}>
                    {p.imageUrl ? (
                      <img src={p.imageUrl} alt={p.name} className="pcard-image-el" />
                    ) : (
                      <span className="pcard-emoji">{p.emoji || '🍽️'}</span>
                    )}
                    <button 
                      className={`pcard-heart ${isProductLiked ? 'liked' : ''}`}
                      onClick={() => handleToggleWishlist(p.id)}
                      aria-label="Wishlist"
                    >
                      <Heart size={14} fill={isProductLiked ? 'currentColor' : 'none'} />
                    </button>
                    <div className="pcard-dots">
                      <span className="pdot on"></span>
                      <span className="pdot"></span>
                      <span className="pdot"></span>
                    </div>
                  </div>

                  {/* Pack Size & ADD Button Overlap Row */}
                  <div className="pcard-action">
                    <span className="pcard-size">{p.unit || p.packSize || '1 unit'}</span>
                    <div className="pcard-add-wrap">
                      <button 
                        className="pcard-add"
                        style={{ display: qty > 0 ? 'none' : 'flex' }}
                        onClick={() => handleAddClick(p)}
                      >
                        ADD
                      </button>
                      <div className={`pcard-qty ${qty > 0 ? 'on' : ''}`}>
                        <button onClick={() => handleRemoveClick(p)}>−</button>
                        <span>{qty}</span>
                        <button onClick={() => handleAddClick(p)}>+</button>
                      </div>
                    </div>
                  </div>

                  {/* Product Details Section */}
                  <div className="pcard-body">
                    <div className="pcard-price-row">
                      <span className="pcard-price">₹{p.price.toLocaleString()}</span>
                      {hasDiscount && (
                        <span className="pcard-mrp">₹{mrpVal.toLocaleString()}</span>
                      )}
                    </div>
                    {hasDiscount ? (
                      <div className="pcard-off">₹{discountVal.toLocaleString()} OFF</div>
                    ) : (
                      <div className="pcard-off" style={{ opacity: 0 }}>No OFF</div>
                    )}
                    <h3 className="pcard-title">{p.name}</h3>
                    <div className="pcard-meta">
                      {(p.stock || p.stockLeft) <= 3 && <span>📦 {p.stock || p.stockLeft} left</span>}
                    </div>
                    <div 
                      className="pcard-link"
                      onClick={() => changeCategory(p.category)}
                    >
                      <span>{categoryLabel}</span>
                      <ChevronRight size={10} strokeWidth={3} />
                    </div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </section>

      {/* See All Products Button */}
      <div className="seeall-wrap">
        <button 
          className="seeall-btn"
          onClick={() => {
            changeCategory(finalCategories[0]?.id || 'all');
            onSeeAll && onSeeAll();
          }}
        >
          <span>🛍️ See all products</span>
          <ChevronRight size={16} />
        </button>
      </div>
    </div>
  );
}
