import { NextResponse } from 'next/server'

// Curated high-aesthetic Unsplash food & grocery photography pool
const AESTHETIC_PHOTOS: Record<string, { hero: string[]; bento: string[] }> = {
  burger: {
    hero: [
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
      'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=800&q=80',
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80',
      'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=400&q=80',
      'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=400&q=80',
      'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=80',
    ],
  },
  pizza: {
    hero: [
      'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&q=80',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400&q=80',
      'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&q=80',
      'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&q=80',
      'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=400&q=80',
    ],
  },
  biryani: {
    hero: [
      'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800&q=80',
      'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400&q=80',
      'https://images.unsplash.com/photo-1589302168068-964664d93dc0?w=400&q=80',
      'https://images.unsplash.com/photo-1633945274405-b6c8069047b0?w=400&q=80',
      'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=400&q=80',
    ],
  },
  fruits: {
    hero: [
      'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=800&q=80',
      'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1610832958506-aa56368176cf?w=400&q=80',
      'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&q=80',
      'https://images.unsplash.com/photo-1519996529931-28324d5a630e?w=400&q=80',
      'https://images.unsplash.com/photo-1587132137056-bfbf0166836e?w=400&q=80',
    ],
  },
  dairy: {
    hero: [
      'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=800&q=80',
      'https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80',
      'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400&q=80',
      'https://images.unsplash.com/photo-1528750997573-59b89d56f4f7?w=400&q=80',
      'https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=400&q=80',
    ],
  },
  snacks: {
    hero: [
      'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=800&q=80',
      'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=400&q=80',
      'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?w=400&q=80',
      'https://images.unsplash.com/photo-1576107232684-1279f3908594?w=400&q=80',
      'https://images.unsplash.com/photo-1621447504864-d8686e12698c?w=400&q=80',
    ],
  },
  desserts: {
    hero: [
      'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=800&q=80',
      'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=800&q=80',
    ],
    bento: [
      'https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=400&q=80',
      'https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=400&q=80',
      'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=400&q=80',
      'https://images.unsplash.com/photo-1509722747041-616f39b57569?w=400&q=80',
    ],
  },
}

function getPhotoPool(categoryName: string, categoryType: string) {
  const name = categoryName.toLowerCase()
  if (name.includes('burg') || name.includes('sandwich') || name.includes('patty')) return AESTHETIC_PHOTOS.burger
  if (name.includes('pizz') || name.includes('italian')) return AESTHETIC_PHOTOS.pizza
  if (name.includes('biryan') || name.includes('rice') || name.includes('roll') || name.includes('tandoor') || name.includes('curry')) return AESTHETIC_PHOTOS.biryani
  if (name.includes('fruit') || name.includes('veg') || name.includes('organic') || name.includes('salad')) return AESTHETIC_PHOTOS.fruits
  if (name.includes('dairy') || name.includes('milk') || name.includes('bread') || name.includes('egg') || name.includes('paneer')) return AESTHETIC_PHOTOS.dairy
  if (name.includes('snack') || name.includes('chip') || name.includes('namkeen') || name.includes('munch')) return AESTHETIC_PHOTOS.snacks
  if (name.includes('sweet') || name.includes('dessert') || name.includes('ice') || name.includes('cake') || name.includes('choco')) return AESTHETIC_PHOTOS.desserts
  
  return categoryType === 'food' ? AESTHETIC_PHOTOS.burger : AESTHETIC_PHOTOS.fruits
}

export async function POST(req: Request) {
  try {
    const body = await req.json()
    const {
      categoryName = 'Burgers & Fast Bites',
      categoryType = 'food', // 'food' or 'grocery'
      cardFormat = 'dark_showcase', // 'dark_showcase' | 'bento_grid' | 'editorial'
      outletName = '',
      apiKey = process.env.GEMINI_API_KEY || '',
    } = body

    const photoPool = getPhotoPool(categoryName, categoryType)
    const heroImage = photoPool.hero[Math.floor(Math.random() * photoPool.hero.length)]
    const bentoImages = photoPool.bento

    // If Gemini API Key is present, invoke Google Gemini 2.5 Flash
    if (apiKey) {
      try {
        const prompt = `You are a world-class luxury quick-commerce creative director for FastKirana (high-speed delivery app).
Create an irresistible, mouth-watering, highly aesthetic promotional card configuration for the category: "${categoryName}" in "${categoryType}" delivery mode.
Card Format: "${cardFormat}" (options: dark_showcase, bento_grid, editorial).
Optional Outlet/Brand: "${outletName || (categoryType === 'food' ? 'A.S. Restaurant / Wedson' : 'FastKirana Direct')}".

Return ONLY a valid JSON object with these EXACT keys:
{
  "eyebrowTag": "Short uppercase punchy badge (e.g. '🔥 SIZZLING FAST DROP', '🌿 100% FARM FRESH', '👑 CHEF\\'S SIGNATURE')",
  "discountTitle": "Bold catchy headline in all-caps (e.g. 'DOUBLE CHEESE BURGER', 'FLAT 50% OFF DUM BIRYANI', 'CRISP ORGANIC GREENS')",
  "subtitle": "Irresistible culinary or freshness description under 8 words (e.g. 'Melted Cheddar • Crispy Patty • Hot Garlic Dip')",
  "primaryBrand": "Short uppercase brand/cuisine name (e.g. '${outletName || (categoryType === 'food' ? 'FAST BITES' : 'FASTKIRANA')}')",
  "secondaryBrand": "Optional accent tag (e.g. 'SPECIAL DROP', 'EXPRESS 10M')",
  "ctaText": "Active conversion button text (e.g. 'ORDER NOW', 'EXPLORE MENU', 'GRAB DEALS')",
  "ctaBgColorHex": "Vibrant hex color (e.g. '#EF4444' or '#10B981' or '#F59E0B' or '#FFFFFF')",
  "ctaTextColorHex": "High contrast hex (e.g. '#FFFFFF' or '#0F172A')",
  "cashbackTitle": "Attractive savings tag (e.g. 'FLAT 40% OFF', 'BUY 1 GET 1 FREE')",
  "cashbackSubtitle": "Cashback or delivery perk (e.g. '+ Extra ₹50 on UPI • Delivered in 15m')",
  "disclaimerText": "Discreet asterisk disclaimer (e.g. '*T&C Apply. Freshly prepared upon order.')",
  "backgroundColorHex": "Deep aesthetic background hex (e.g. '#09090B' or '#18181B' or '#1E1B4B')"
}`

        const geminiRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: {
                responseMimeType: 'application/json',
                temperature: 0.7,
              },
            }),
          }
        )

        if (geminiRes.ok) {
          const geminiData = await geminiRes.json()
          const text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text
          if (text) {
            const parsed = JSON.parse(text)
            return NextResponse.json({
              success: true,
              generatedBy: 'gemini-2.5-flash',
              card: {
                ...parsed,
                cardType: cardFormat,
                imageUrl: heroImage,
                gridImages: bentoImages,
                hasWireframeGrid: cardFormat === 'dark_showcase',
                ctaUrl: categoryType === 'food' ? `/category/${categoryName.toLowerCase().replace(/\s+/g, '-')}` : `/category/${categoryName.toLowerCase().replace(/\s+/g, '-')}`,
              },
            })
          }
        }
      } catch (geminiErr) {
        console.warn('Gemini API call failed, using intelligent creative fallback:', geminiErr)
      }
    }

    // Intelligent Creative Fallback when API key is not yet set
    const isFood = categoryType === 'food'
    const fallbackTitle = isFood
      ? categoryName.toUpperCase().includes('BURGER')
        ? 'DOUBLE CHEESE CRUNCH'
        : categoryName.toUpperCase().includes('PIZZA')
        ? 'LOADED CHEESY CRUST'
        : categoryName.toUpperCase().includes('BIRYANI')
        ? 'ROYAL DUM BIRYANI'
        : `${categoryName.toUpperCase()} SPECIAL`
      : categoryName.toUpperCase().includes('FRUIT')
      ? 'FARM FRESH GREENS'
      : categoryName.toUpperCase().includes('DAIRY')
      ? 'FARM MILK & BAKERY'
      : categoryName.toUpperCase().includes('SNACK')
      ? 'MUNCHIES & SODAS'
      : `${categoryName.toUpperCase()} STAPLES`

    const fallbackSubtitle = isFood
      ? 'Hot, fresh & delivered piping hot in 15 mins'
      : 'Handpicked daily harvest delivered in 10 mins'

    return NextResponse.json({
      success: true,
      generatedBy: 'creative-engine',
      card: {
        cardType: cardFormat,
        eyebrowTag: isFood ? '🔥 SIZZLING FAST FOOD' : '🌿 DAILY HARVEST',
        discountTitle: fallbackTitle,
        subtitle: fallbackSubtitle,
        primaryBrand: outletName || (isFood ? 'A.S. RESTAURANT' : 'FASTKIRANA'),
        secondaryBrand: isFood ? 'FAST BITES' : 'DIRECT',
        imageUrl: heroImage,
        gridImages: bentoImages,
        hasWireframeGrid: cardFormat === 'dark_showcase',
        ctaText: isFood ? 'ORDER NOW' : 'SHOP FRESH',
        ctaUrl: `/category/${categoryName.toLowerCase().replace(/[^a-z0-9]+/g, '-')}`,
        ctaBgColorHex: isFood ? '#EF4444' : '#10B981',
        ctaTextColorHex: '#FFFFFF',
        cashbackTitle: 'FLAT 40% OFF',
        cashbackSubtitle: '+ Extra ₹50 on UPI Payment',
        disclaimerText: '*T&C Apply. Superfast express delivery in Ghatampur.',
        backgroundColorHex: '#0F172A',
      },
    })
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to generate card' },
      { status: 500 }
    )
  }
}
