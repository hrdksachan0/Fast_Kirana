"""
Gemini AI Query Intent & Conversational Parser
Fastkirana Quick-Commerce Backend
"""

import os
import json
import urllib.request
import logging
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)

# In-memory cache for parsed intents
_INTENT_CACHE: Dict[str, Dict[str, Any]] = {}

CONVERSATIONAL_MARKERS = {
    'kuch', 'chahiye', 'khana', 'peena', 'meetha', 'namkeen', 'halka', 'pet', 'kharab',
    'banana', 'banane', 'saman', 'recipe', 'party', 'subah', 'nashta', 'raat', 'dinner',
    'lunch', 'bhookh', 'craving', 'sweet', 'spicy', 'garam', 'thanda', 'veg', 'nonveg', 'non-veg'
}

def should_parse_intent(query: str) -> bool:
    clean = query.lower().strip()
    words = clean.split()
    if len(words) >= 3:
        return True
    if any(w in CONVERSATIONAL_MARKERS for w in words):
        return True
    return False

def parse_query_intent_with_gemini(raw_query: str) -> Optional[Dict[str, Any]]:
    query = raw_query.lower().strip()
    if not query or len(query) < 3:
        return None

    if query in _INTENT_CACHE:
        return _INTENT_CACHE[query]

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return None

    prompt = f"""You are the AI Search & Intent Engine for Fastkirana quick-commerce (grocery + restaurant food delivery in India).
The customer typed this search query: "{query}"

Deconstruct their intent into strictly valid JSON matching this schema:
{{
  "intent": "craving_dessert" | "cooked_meal" | "cooking_recipe" | "grocery_staple" | "restaurant_search" | "health_comfort" | "general",
  "dietary": "veg" | "non_veg" | "all",
  "search_terms": ["2 to 5 relevant product names in English/Hinglish to query in catalog"],
  "is_recipe_basket": boolean,
  "recipe_items": ["ingredients if recipe, else empty"],
  "mood_summary": "1 short sentence explaining what the user wants"
}}

Output raw JSON only without markdown formatting or code blocks."""

    try:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {
                "temperature": 0.1,
                "maxOutputTokens": 256
            }
        }
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
        
        with urllib.request.urlopen(req, timeout=8) as resp:
            res_data = json.loads(resp.read().decode('utf-8'))
            raw_text = res_data.get('candidates', [{}])[0].get('content', {}).get('parts', [{}])[0].get('text', '')
            clean_json = raw_text.replace("```json", "").replace("```", "").strip()
            parsed = json.loads(clean_json)
            
            if isinstance(parsed, dict) and 'search_terms' in parsed:
                if len(_INTENT_CACHE) > 500:
                    _INTENT_CACHE.clear()
                _INTENT_CACHE[query] = parsed
                return parsed
    except Exception as e:
        logger.warning(f"[GeminiIntentParser] fallback on '{query}': {e}")
        
    return None
