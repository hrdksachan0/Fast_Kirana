import os
import urllib.request
import json
import logging

logger = logging.getLogger("gemini_embedding")

_query_cache: dict[str, list[float]] = {}
MAX_CACHE_SIZE = 500

def get_query_embedding(query: str) -> list[float] | None:
    q = (query or "").strip().lower()
    if not q or len(q) < 2:
        return None
        
    if q in _query_cache:
        return _query_cache[q]
        
    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        return None
        
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key={api_key}"
    payload = {
        "model": "models/gemini-embedding-001",
        "content": {"parts": [{"text": q}]},
        "outputDimensionality": 768
    }
    
    try:
        data_bytes = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(url, data=data_bytes, headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=2.5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            emb = data.get("embedding", {}).get("values")
            if emb and len(emb) == 768:
                if len(_query_cache) >= MAX_CACHE_SIZE:
                    _query_cache.pop(next(iter(_query_cache)))
                _query_cache[q] = emb
                return emb
    except Exception as e:
        logger.warning(f"Error fetching query embedding: {e}")
        
    return None
