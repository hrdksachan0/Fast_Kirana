/**
 * Supabase PgVector & Semantic Hybrid AI Search Engine for FastKirana
 * Handles natural Hinglish/Hindi/English intent queries, synonyms, and fuzzy matching.
 */

// Intent-to-Category/Tag Mapping Matrix for Semantic AI Search
const SEMANTIC_INTENT_MAP: Record<string, { categories: string[]; tags: string[]; boostKeywords: string[] }> = {
  // Cold / Summer / Chilled Intent
  garmi: {
    categories: ['beverages', 'ice-cream', 'cafe-cold-drinks', 'cafe-shakes', 'cafe-mocktails', 'cafe-coffee'],
    tags: ['chilled', 'cold-drink', 'ice-cream', 'shakes', 'mocktails', 'cold-coffee', 'juice', 'soda'],
    boostKeywords: ['amul', 'coke', 'pepsi', 'sprite', 'thums up', 'frooti', 'real', 'ice cream', 'cold coffee', 'limca', 'appie', 'sting', 'red bull']
  },
  thanda: {
    categories: ['beverages', 'ice-cream', 'cafe-cold-drinks', 'cafe-shakes', 'cafe-mocktails'],
    tags: ['chilled', 'cold-drink', 'ice-cream', 'shakes', 'juice', 'soda'],
    boostKeywords: ['amul', 'coke', 'pepsi', 'sprite', 'ice cream', 'cold coffee', 'frooti', 'juice']
  },
  summer: {
    categories: ['beverages', 'ice-cream', 'cafe-cold-drinks', 'cafe-shakes'],
    tags: ['chilled', 'cold-drink', 'ice-cream', 'juice'],
    boostKeywords: ['coke', 'pepsi', 'sprite', 'ice cream', 'frooti', 'juice']
  },

  // Breakfast / Subah Intent
  nashta: {
    categories: ['dairy-breakfast', 'bakery-biscuits', 'snacks-munchies'],
    tags: ['milk', 'bread', 'eggs', 'butter', 'dahi', 'oats', 'cornflakes', 'tea', 'biscuit'],
    boostKeywords: ['milk', 'bread', 'amul', 'butter', 'paneer', 'dahi', 'eggs', 'maggi', 'oats', 'rusk', 'poha']
  },
  subah: {
    categories: ['dairy-breakfast', 'bakery-biscuits'],
    tags: ['milk', 'bread', 'eggs', 'butter', 'dahi', 'tea'],
    boostKeywords: ['milk', 'bread', 'amul', 'butter', 'dahi', 'eggs', 'poha', 'tea']
  },
  breakfast: {
    categories: ['dairy-breakfast', 'bakery-biscuits'],
    tags: ['milk', 'bread', 'eggs', 'butter', 'dahi', 'oats', 'cornflakes'],
    boostKeywords: ['milk', 'bread', 'butter', 'dahi', 'eggs', 'oats', 'cornflakes']
  },

  // Tea Time / Chai ke sath / Evening Intent
  chai: {
    categories: ['bakery-biscuits', 'snacks-munchies', 'dairy-breakfast'],
    tags: ['tea', 'biscuit', 'namkeen', 'toast', 'rusk', 'cookies'],
    boostKeywords: ['tea', 'chai', 'parle-g', 'good day', 'marie', 'rusk', 'toast', 'bhujia', 'namkeen', 'monaco', 'krackjack', 'hide & seek']
  },
  snack: {
    categories: ['snacks-munchies', 'bakery-biscuits', 'cafe-snacks'],
    tags: ['chips', 'namkeen', 'biscuits', 'munchies', 'kurkure', 'lays'],
    boostKeywords: ['lays', 'kurkure', 'bingo', 'haldiram', 'bhujia', 'parle-g', 'good day', 'chips', 'nachos']
  },
  munchies: {
    categories: ['snacks-munchies', 'bakery-biscuits'],
    tags: ['chips', 'namkeen', 'biscuits', 'kurkure'],
    boostKeywords: ['lays', 'kurkure', 'bingo', 'bhujia', 'chips']
  },

  // Sweet / Dessert / Meetha Intent
  meetha: {
    categories: ['ice-cream', 'cafe-desserts', 'bakery-biscuits'],
    tags: ['chocolate', 'sweets', 'ice-cream', 'mithai', 'dessert'],
    boostKeywords: ['cadbury', 'dairy milk', 'kitkat', '5 star', 'snickers', 'ice cream', 'gulab jamun', 'mithai', 'chocolate']
  },
  sweet: {
    categories: ['ice-cream', 'cafe-desserts', 'bakery-biscuits'],
    tags: ['chocolate', 'sweets', 'ice-cream', 'mithai'],
    boostKeywords: ['cadbury', 'dairy milk', 'kitkat', 'ice cream', 'chocolate']
  },
  dessert: {
    categories: ['ice-cream', 'cafe-desserts'],
    tags: ['ice-cream', 'chocolate', 'sweets'],
    boostKeywords: ['ice cream', 'cadbury', 'pastry', 'cake']
  },

  // Cooking / Masala / Meal Intent
  khana: {
    categories: ['atta-rice-dal', 'fruits-vegetables', 'household'],
    tags: ['atta', 'rice', 'dal', 'oil', 'spices', 'ghee', 'vegetables'],
    boostKeywords: ['atta', 'rice', 'dal', 'fortune', 'oil', 'ghee', 'masala', 'potato', 'onion', 'tomato']
  },
  cooking: {
    categories: ['atta-rice-dal', 'fruits-vegetables'],
    tags: ['atta', 'rice', 'dal', 'oil', 'spices', 'ghee'],
    boostKeywords: ['atta', 'rice', 'dal', 'oil', 'ghee', 'masala']
  },
  masala: {
    categories: ['atta-rice-dal', 'fruits-vegetables'],
    tags: ['spices', 'masala'],
    boostKeywords: ['masala', 'turmeric', 'chilli', 'coriander', 'garam masala', 'maggi masala', 'salt', 'jeera']
  },

  // Health / Protein / Gym Intent
  health: {
    categories: ['dairy-breakfast', 'fruits-vegetables', 'atta-rice-dal'],
    tags: ['oats', 'eggs', 'almonds', 'milk', 'peanut-butter', 'fruit'],
    boostKeywords: ['oats', 'eggs', 'milk', 'almond', 'badam', 'peanut butter', 'honey', 'apple', 'banana']
  },
  protein: {
    categories: ['dairy-breakfast', 'atta-rice-dal'],
    tags: ['eggs', 'milk', 'paneer', 'oats', 'peanut-butter', 'dal'],
    boostKeywords: ['eggs', 'paneer', 'milk', 'oats', 'peanut butter', 'dal', 'soya']
  },

  // Pooja / Festival Intent
  pooja: {
    categories: ['household'],
    tags: ['pooja', 'agarbatti', 'dhoop', 'kapoor'],
    boostKeywords: ['agarbatti', 'dhoop', 'kapoor', 'oil', 'matchbox', 'diya']
  },
  puja: {
    categories: ['household'],
    tags: ['pooja', 'agarbatti', 'dhoop', 'kapoor'],
    boostKeywords: ['agarbatti', 'dhoop', 'kapoor', 'oil']
  }
}

// Synonyms map
const SYNONYM_MAP: Record<string, string[]> = {
  aalu: ['potato', 'aloo'],
  aloo: ['potato', 'aalu'],
  pyaz: ['onion', 'pyaj'],
  pyaj: ['onion', 'pyaz'],
  doodh: ['milk', 'dudh'],
  dudh: ['milk', 'doodh'],
  dahi: ['curd', 'yogurt'],
  anda: ['egg', 'eggs'],
  tamatar: ['tomato', 'tomatoes'],
  makhan: ['butter'],
  nimbu: ['lemon', 'lime'],
  chai: ['tea'],
  patti: ['tea'],
  pani: ['water'],
  chawal: ['rice'],
  chini: ['sugar'],
  namak: ['salt'],
  tel: ['oil'],
  biskut: ['biscuit', 'biscuits'],
  biscuit: ['biscuits', 'biskut'],
  bhujia: ['namkeen', 'sev'],
  namkeen: ['bhujia', 'munchies'],
  colddrink: ['cold drink', 'soda', 'coke', 'pepsi'],
}

/**
 * Calculates semantic AI score for a product given a query
 */
export function getSemanticAiScore(query: string, product: any): number {
  const q = query.toLowerCase().trim()
  const pName = (product.name || '').toLowerCase()
  const pDesc = (product.description || '').toLowerCase()
  const pTags: string[] = (product.tags || []).map((t: string) => t.toLowerCase())
  const categorySlug = (product.category?.slug || '').toLowerCase()

  let totalScore = 0

  // 1. Direct Substring Match (Weight 100)
  if (pName.includes(q)) {
    totalScore += 100
  }

  // 2. Token Word Matches & Synonyms (Weight 85)
  const qWords = q.split(/\s+/)
  for (const qw of qWords) {
    const syns = SYNONYM_MAP[qw] || []
    const searchVariants = [qw, ...syns]

    for (const variant of searchVariants) {
      if (pName.includes(variant)) {
        totalScore += 80
      } else if (pTags.some(t => t.includes(variant))) {
        totalScore += 65
      } else if (categorySlug.includes(variant)) {
        totalScore += 50
      } else if (pDesc.includes(variant)) {
        totalScore += 40
      }
    }
  }

  // 3. Natural Language Intent Semantic AI Match (Weight 75)
  for (const qw of qWords) {
    const intent = SEMANTIC_INTENT_MAP[qw]
    if (intent) {
      // Category match
      if (intent.categories.some(c => categorySlug.includes(c))) {
        totalScore += 70
      }
      // Tag match
      if (intent.tags.some(t => pTags.includes(t) || pTags.some(pt => pt.includes(t)))) {
        totalScore += 60
      }
      // Boost keywords match
      if (intent.boostKeywords.some(bk => pName.includes(bk) || pDesc.includes(bk))) {
        totalScore += 80
      }
    }
  }

  return Math.min(Math.round(totalScore), 100)
}
