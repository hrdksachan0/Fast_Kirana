/**
 * Gemini AI Query Intent & Conversational Parser
 * Fastkirana Quick-Commerce Brain
 * 
 * Understands:
 * 1. Moods & Cravings ("aaj kuch meetha khana hai", "chai ke sath namkeen")
 * 2. Recipe & Cooking Intent ("biryani banana hai masale aur rice", "pav bhaji ka saman")
 * 3. Dietary preferences ("veg burger", "nonveg dinner")
 * 4. Health & Occasions ("pet kharab hai halka khana", "party snacks")
 */

import { LRUCache } from 'lru-cache'

export interface ParsedSearchIntent {
  intent: 'craving_dessert' | 'cooked_meal' | 'cooking_recipe' | 'grocery_staple' | 'restaurant_search' | 'health_comfort' | 'general'
  dietary: 'veg' | 'non_veg' | 'all'
  search_terms: string[]
  is_recipe_basket: boolean
  recipe_items: string[]
  mood_summary?: string
}

// In-memory cache for intent results so repeated queries take 0ms
const intentCache = new LRUCache<string, ParsedSearchIntent>({
  max: 500,
  ttl: 1000 * 60 * 60 * 24, // 24 hours
})

const CONVERSATIONAL_MARKERS = new Set([
  'kuch', 'chahiye', 'khana', 'peena', 'meetha', 'namkeen', 'halka', 'pet', 'kharab',
  'banana', 'banane', 'saman', 'recipe', 'party', 'subah', 'nashta', 'raat', 'dinner',
  'lunch', 'bhookh', 'craving', 'sweet', 'spicy', 'garam', 'thanda', 'veg', 'nonveg', 'non-veg'
])

export function shouldParseIntent(query: string): boolean {
  const clean = query.toLowerCase().trim()
  const words = clean.split(/\s+/).filter(Boolean)
  
  // If query is 3+ words or has strong conversational markers
  if (words.length >= 3) return true
  if (words.some(w => CONVERSATIONAL_MARKERS.has(w))) return true
  
  return false
}

export async function parseQueryIntentWithGemini(rawQuery: string): Promise<ParsedSearchIntent | null> {
  const query = rawQuery.toLowerCase().trim()
  if (!query || query.length < 3) return null

  // Check cache first
  const cached = intentCache.get(query)
  if (cached) return cached

  const apiKey = process.env.GEMINI_API_KEY
  if (!apiKey) return null

  const prompt = `You are the AI Search & Intent Engine for Fastkirana quick-commerce (grocery + restaurant food delivery in India).
The customer typed this search query: "${query}"

Deconstruct their intent into strictly valid JSON matching this schema:
{
  "intent": "craving_dessert" | "cooked_meal" | "cooking_recipe" | "grocery_staple" | "restaurant_search" | "health_comfort" | "general",
  "dietary": "veg" | "non_veg" | "all",
  "search_terms": ["2 to 5 relevant product names in English/Hinglish to query in catalog"],
  "is_recipe_basket": boolean,
  "recipe_items": ["ingredients if recipe, else empty"],
  "mood_summary": "1 short sentence explaining what the user wants"
}

Examples:
- "aaj kuch meetha khana hai" -> intent: "craving_dessert", dietary: "all", search_terms: ["ice cream", "gulab jamun", "dark fantasy", "chocolate", "rasgulla"], is_recipe_basket: false
- "chai ke sath namkeen" -> intent: "craving_dessert", dietary: "veg", search_terms: ["rusk", "biscuit", "namkeen", "bhujia", "tea"], is_recipe_basket: false
- "pet kharab hai halka khana" -> intent: "health_comfort", dietary: "veg", search_terms: ["dahi", "curd", "khichdi rice", "bread", "ors"], is_recipe_basket: false
- "biryani banana hai masale aur rice" -> intent: "cooking_recipe", dietary: "all", search_terms: ["basmati rice", "biryani masala", "ghee", "chicken masala"], is_recipe_basket: true, recipe_items: ["rice", "masala", "ghee"]
- "pure veg pizza" -> intent: "cooked_meal", dietary: "veg", search_terms: ["veg pizza", "cheese pizza", "paneer pizza"], is_recipe_basket: false

Output raw JSON only without markdown formatting or code blocks.`

  try {
    const controller = new AbortController()
    const timeout = setTimeout(() => controller.abort(), 2000) // Fast 2s timeout

    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 256,
        }
      }),
      signal: controller.signal
    })

    clearTimeout(timeout)
    if (!res.ok) return null

    const data = await res.json()
    const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text
    if (!rawText) return null

    const cleanJson = rawText.replace(/```json\s*/gi, '').replace(/```\s*/gi, '').trim()
    const parsed: ParsedSearchIntent = JSON.parse(cleanJson)

    if (parsed && parsed.search_terms && Array.isArray(parsed.search_terms)) {
      intentCache.set(query, parsed)
      return parsed
    }
  } catch (err) {
    // Graceful fallback to standard search on timeout or error
    console.warn('[GeminiIntentParser] fallback:', err)
  }

  return null
}
