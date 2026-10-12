"""
Search Service for FastKirana FastAPI Backend
Handles Hinglish synonym mapping, fuzzy matching, and Levenshtein distance calculations.
"""

from typing import List, Set, Dict

# Comprehensive Synonym dictionary for Hinglish / English / Brands / Everyday Grocery
SYNONYM_DICTIONARY: Dict[str, List[str]] = {
    # 🥔 Vegetables & Fresh
    'aalu': ['potato', 'aloo', 'potatoes'],
    'aloo': ['potato', 'aalu', 'potatoes'],
    'potato': ['aloo', 'aalu', 'potatoes'],
    'potatoes': ['aloo', 'aalu', 'potato'],
    'pyaz': ['onion', 'pyaj', 'kanda', 'onions'],
    'pyaj': ['onion', 'pyaz', 'kanda', 'onions'],
    'kanda': ['onion', 'pyaz', 'pyaj'],
    'onion': ['pyaz', 'pyaj', 'kanda', 'onions'],
    'onions': ['pyaz', 'pyaj', 'kanda', 'onion'],
    'tamatar': ['tomato', 'tomatoes'],
    'tomato': ['tamatar', 'tomatoes'],
    'tomatoes': ['tamatar', 'tomato'],
    'nimbu': ['lemon', 'lime'],
    'lemon': ['nimbu', 'lime'],
    'adrak': ['ginger'],
    'ginger': ['adrak'],
    'lahsun': ['garlic', 'lehsun'],
    'lehsun': ['garlic', 'lahsun'],
    'garlic': ['lahsun', 'lehsun'],
    'mirch': ['chilli', 'chili', 'mirchi', 'green chilli', 'red chilli'],
    'mirchi': ['chilli', 'chili', 'mirch'],
    'chilli': ['mirch', 'mirchi', 'green chilli', 'red chilli'],
    'chili': ['mirch', 'mirchi', 'green chilli'],
    'hari mirch': ['green chilli', 'chilli', 'mirch'],
    'lal mirch': ['red chilli', 'chilli', 'mirch'],
    'dhaniya': ['coriander', 'cilantro'],
    'coriander': ['dhaniya'],
    'kheera': ['cucumber', 'khira'],
    'cucumber': ['kheera'],
    'gobi': ['cauliflower', 'cabbage', 'gobhi'],
    'patta gobi': ['cabbage', 'band gobhi'],
    'phool gobi': ['cauliflower', 'gobhi'],
    'cabbage': ['patta gobi', 'gobi'],
    'cauliflower': ['phool gobi', 'gobi'],
    'matar': ['peas', 'green peas', 'muttar'],
    'peas': ['matar', 'green peas'],
    'bhindi': ['lady finger', 'okra', 'bhendi'],
    'lady finger': ['bhindi', 'okra'],

    # 🥛 Dairy & Breakfast
    'doodh': ['milk', 'dudh', 'amul', 'amul milk', 'dairy'],
    'dudh': ['milk', 'doodh', 'amul', 'amul milk', 'dairy'],
    'milk': ['doodh', 'dudh', 'amul', 'dairy', 'cow milk'],
    'dahi': ['curd', 'yogurt', 'amul masti'],
    'curd': ['dahi', 'yogurt'],
    'yogurt': ['dahi', 'curd'],
    'makhan': ['butter', 'amul butter', 'white butter'],
    'butter': ['makhan', 'amul butter', 'amul'],
    'paneer': ['cottage cheese', 'amul paneer', 'fresh paneer'],
    'cheese': ['paneer', 'amul cheese', 'slice cheese'],
    'ghee': ['clarified butter', 'desi ghee', 'amul ghee'],
    'desi ghee': ['ghee', 'amul ghee'],
    'chhaas': ['buttermilk', 'chach', 'mattha', 'amul masti'],
    'chach': ['buttermilk', 'chhaas', 'mattha'],
    'lassi': ['buttermilk', 'sweet lassi', 'amul'],
    'anda': ['egg', 'eggs', 'white eggs'],
    'ande': ['egg', 'eggs', 'white eggs'],
    'egg': ['anda', 'ande', 'eggs'],
    'eggs': ['anda', 'ande', 'egg'],
    'bread': ['pav', 'bun', 'loaf', 'white bread', 'brown bread', 'harvest'],
    'pav': ['bread', 'bun'],
    'bun': ['bread', 'pav'],
    'rusk': ['toast', 'biscuit', 'britannia rusk', 'toast rusk'],
    'toast': ['rusk', 'biscuit'],
    'chai': ['tea', 'taj mahal', 'tata tea', 'red label', 'patti'],
    'tea': ['chai', 'tata tea', 'red label', 'taj mahal', 'patti'],
    'patti': ['tea', 'chai', 'chai patti'],
    'coffee': ['nescafe', 'bru', 'instant coffee'],
    'nescafe': ['coffee'],
    'bru': ['coffee'],

    # 🌾 Staples & Grains
    'atta': ['flour', 'wheat', 'gehu', 'ashirvaad', 'chakki atta', 'aata'],
    'aata': ['flour', 'wheat', 'gehu', 'ashirvaad', 'chakki atta', 'atta'],
    'flour': ['atta', 'aata', 'maida', 'besan'],
    'chawal': ['rice', 'basmati', 'fortune rice', 'daawat'],
    'rice': ['chawal', 'basmati', 'fortune', 'daawat'],
    'dal': ['pulse', 'lentil', 'daal', 'toor dal', 'moong dal', 'chana dal', 'urad dal'],
    'daal': ['pulse', 'lentil', 'dal', 'toor dal', 'moong dal'],
    'toor dal': ['arhar dal', 'tuvar dal', 'dal'],
    'arhar dal': ['toor dal', 'dal'],
    'moong dal': ['moong', 'dal', 'yellow dal', 'green moong'],
    'chana dal': ['chana', 'dal', 'bengal gram'],
    'urad dal': ['urad', 'dal', 'black gram', 'white urad'],
    'rajma': ['kidney beans', 'chitra rajma'],
    'chole': ['chana', 'kabuli chana', 'chickpeas'],
    'chana': ['chole', 'chana dal', 'chickpeas', 'black chana'],
    'tel': ['oil', 'mustard oil', 'sunflower oil', 'fortune', 'kachi ghani'],
    'oil': ['tel', 'mustard oil', 'cooking oil', 'fortune', 'nature fresh'],
    'sarson tel': ['mustard oil', 'kachi ghani', 'fortune'],
    'mustard oil': ['sarson tel', 'kachi ghani', 'oil'],
    'refined oil': ['sunflower oil', 'soya oil', 'oil'],
    'namak': ['salt', 'tata salt', 'sendha namak'],
    'salt': ['namak', 'tata salt'],
    'cheeni': ['sugar', 'chini', 'mishri'],
    'chini': ['sugar', 'cheeni'],
    'sugar': ['cheeni', 'chini'],
    'gur': ['jaggery', 'gud'],
    'jaggery': ['gur', 'gud'],
    'besan': ['gram flour', 'chana flour'],
    'maida': ['refined wheat flour', 'all purpose flour'],
    'sooji': ['suji', 'semolina', 'rawa'],
    'suji': ['sooji', 'semolina', 'rawa'],
    'poha': ['flattened rice', 'chivda', 'chiwda'],

    # 🍿 Snacks & Instant Foods
    'maggi': ['noodles', 'instant noodles', 'maggie', 'magi', 'megi', 'meggi', 'nestle', 'noodle', 'yippee', 'chowmein', 'wai wai'],
    'maggie': ['maggi', 'noodles', 'instant noodles', 'magi', 'megi', 'meggi', 'nestle', 'noodle', 'yippee', 'chowmein', 'wai wai'],
    'magi': ['maggi', 'maggie', 'noodles', 'instant noodles', 'megi', 'meggi', 'noodle'],
    'magie': ['maggi', 'maggie', 'noodles', 'instant noodles', 'megi', 'meggi', 'noodle'],
    'megi': ['maggi', 'maggie', 'noodles', 'instant noodles', 'magi', 'meggi', 'noodle'],
    'meggi': ['maggi', 'maggie', 'noodles', 'instant noodles', 'magi', 'megi', 'noodle'],
    'magg': ['maggi', 'maggie', 'noodles', 'instant noodles', 'magi', 'megi'],
    'noodle': ['maggi', 'maggie', 'noodles', 'instant noodles', 'chowmein', 'yippee', 'wai wai'],
    'noodles': ['maggi', 'maggie', 'noodle', 'instant noodles', 'chowmein', 'yippee', 'wai wai'],
    'instant noodles': ['maggi', 'maggie', 'noodles', 'noodle', 'yippee'],
    'nestle': ['maggi', 'maggie', 'kitkat', 'everyday', 'milkmaid'],
    'yippee': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'chowmein': ['noodles', 'noodle', 'maggi', 'hakka noodles', 'chings'],
    'wai wai': ['maggi', 'maggie', 'noodles'],
    'waiwai': ['maggi', 'maggie', 'noodles'],
    # Multi-word Maggi phrases
    'maggi noodles': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'maggie noodles': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'maggi masala': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'maggie masala': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'maggi packet': ['maggi', 'maggie', 'noodles'],
    'maggi 2 minute': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'maggie 2 minute': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    '2 minute maggi': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    '2 min maggi': ['maggi', 'maggie', 'noodles', 'instant noodles'],
    'pasta': ['macaroni', 'penne', 'spaghetti'],
    'chips': ['lays', 'kurkure', 'bingo', 'potato chips', 'wafer'],
    'lays': ['chips', 'potato chips'],
    'kurkure': ['chips', 'namkeen', 'snack'],
    'biscuit': ['biscuits', 'cookies', 'parle-g', 'good day', 'marie gold', 'oreo', 'biskut'],
    'biscuits': ['biscuit', 'cookies', 'parle-g', 'good day', 'biskut'],
    'biskut': ['biscuit', 'biscuits', 'parle-g', 'good day', 'cookies'],
    'biscut': ['biscuit', 'biscuits', 'parle-g', 'good day', 'cookies'],
    'biskit': ['biscuit', 'biscuits', 'parle-g', 'cookies'],
    'parle': ['parle-g', 'biscuit', 'biscuits', 'rusk'],
    'parle-g': ['biscuit', 'parle', 'biscuits'],
    'cookie': ['cookies', 'biscuit'],
    'cookies': ['cookie', 'biscuits'],
    'namkeen': ['bhujia', 'snack', 'haldiram', 'bikano', 'mixture', 'sev'],
    'bhujia': ['namkeen', 'aloo bhujia', 'haldiram bhujia'],
    'chocolate': ['chocolates', 'cadbury', 'dairy milk', 'kitkat', '5 star', 'munch'],
    'chocolates': ['chocolate', 'cadbury'],
    'choclat': ['chocolate', 'cadbury', 'dairy milk'],
    'choklet': ['chocolate', 'cadbury'],

    # 🥤 Beverages & Drinks
    'cold drink': ['soda', 'coke', 'pepsi', 'sprite', 'thumbs up', 'thums up', '7up', 'fanta', 'frooti'],
    'soft drink': ['cold drink', 'soda', 'coke', 'pepsi', 'sprite'],
    'coke': ['coca cola', 'cold drink', 'pepsi'],
    'pepsi': ['coke', 'cold drink'],
    'sprite': ['7up', 'cold drink', 'limca'],
    'thums up': ['thumbs up', 'coke', 'cold drink'],
    'thumbs up': ['thums up', 'coke', 'cold drink'],
    'frooti': ['mango drink', 'slice', 'maaza', 'juice'],
    'maaza': ['mango drink', 'frooti', 'slice', 'juice'],
    'slice': ['mango drink', 'frooti', 'maaza'],
    'juice': ['real juice', 'tropicana', 'fruit juice', 'frooti', 'maaza'],
    'water': ['bisleri', 'minera water', 'drinking water', 'kinley', 'aquafina'],
    'bisleri': ['water', 'drinking water'],

    # 🧹 Household & Cleaning
    'sabun': ['soap', 'bathing soap', 'lux', 'dettol', 'lifebuoy', 'dove'],
    'soap': ['sabun', 'bathing soap', 'lux', 'dettol', 'dove'],
    'surf': ['washing powder', 'detergent', 'surf excel', 'tide', 'ariel', 'wheel', 'ghadi'],
    'serf': ['surf', 'washing powder', 'detergent', 'surf excel'],
    'sarf': ['surf', 'washing powder', 'detergent', 'surf excel'],
    'detergent': ['surf', 'washing powder', 'surf excel', 'tide', 'ariel', 'wheel', 'ghadi'],
    'washing powder': ['detergent', 'surf', 'surf excel', 'tide', 'ghadi'],
    'ghadi': ['detergent', 'washing powder', 'surf'],
    'vessel cleaner': ['vim', 'dishwash', 'pril'],
    'vim': ['dishwash', 'vim bar', 'vim gel', 'dishwash tub'],
    'dishwash': ['vim', 'dishwash bar', 'dishwash gel', 'pril'],
    'harpic': ['toilet cleaner', 'bathroom cleaner'],
    'toilet cleaner': ['harpic', 'domex'],
    'phenyl': ['floor cleaner', 'lizol'],
    'lizol': ['floor cleaner', 'phenyl'],

    # 🧴 Personal Care & Hygiene
    'shampoo': ['hair wash', 'clinic plus', 'head and shoulders', 'pantene', 'dove shampoo', 'sunsilk'],
    'paste': ['toothpaste', 'colgate', 'close up', 'pepsodent', 'sensodyne', 'dant kanti'],
    'toothpaste': ['paste', 'colgate', 'close up', 'dant kanti', 'sensodyne'],
    'colgate': ['toothpaste', 'paste'],
    'colgit': ['colgate', 'toothpaste', 'paste'],
    'kolget': ['colgate', 'toothpaste', 'paste'],
    'oil hair': ['hair oil', 'coconut oil', 'navratna', 'parachute', 'almond oil'],
    'hair oil': ['coconut oil', 'parachute', 'navratna', 'almond oil', 'amla oil'],
    'parachute': ['coconut oil', 'hair oil'],
    'pad': ['pads', 'whisper', 'stayfree', 'sanitary pads', 'sofy'],
    'pads': ['pad', 'whisper', 'stayfree', 'sanitary pads'],
    'whisper': ['pad', 'pads', 'sanitary pads', 'stayfree'],
    'stayfree': ['pad', 'pads', 'sanitary pads', 'whisper'],

    # 🪔 Pooja & Local Essentials
    'agarbatti': ['incense sticks', 'dhoop', 'cycle agarbatti', 'mangaldeep', 'pooja'],
    'dhoop': ['agarbatti', 'incense sticks', 'pooja'],
    'matchbox': ['machis', 'matches', 'homelites'],
    'machis': ['matchbox', 'matches', 'homelites'],
    'kapoor': ['camphor', 'pooja kapoor', 'arti'],
    'camphor': ['kapoor', 'pooja'],
}


def get_levenshtein_distance(a: str, b: str) -> int:
    """Levenshtein distance calculation in Python."""
    if len(a) < len(b):
        return get_levenshtein_distance(b, a)
    if len(b) == 0:
        return len(a)

    previous_row = range(len(b) + 1)
    for i, c1 in enumerate(a):
        current_row = [i + 1]
        for j, c2 in enumerate(b):
            insertions = previous_row[j + 1] + 1
            deletions = current_row[j] + 1
            substitutions = previous_row[j] + (0 if c1 == c2 else 1)
            current_row.append(min(insertions, deletions, substitutions))
        previous_row = current_row

    return previous_row[-1]


def get_fuzzy_score(query: str, target: str) -> float:
    """Fuzzy matching logic with strict 70% threshold and initial letter guards."""
    q = query.lower().strip()
    t = target.lower().strip()

    if q in t:
        return 100.0

    q_words = q.split()
    t_words = t.split()

    if not q_words or not t_words:
        return 0.0

    total_score = 0.0
    for qw in q_words:
        best_word_score = 0.0
        for tw in t_words:
            if tw == qw:
                best_word_score = max(best_word_score, 90.0)
            elif (len(qw) >= 4 and qw in tw) or (len(tw) >= 4 and tw in qw):
                best_word_score = max(best_word_score, 70.0)
            else:
                if len(qw) <= 3:
                    continue
                # Typos overwhelmingly share the first letter
                if qw[0] != tw[0]:
                    continue
                dist = get_levenshtein_distance(qw, tw)
                max_len = max(len(qw), len(tw))
                if max_len > 0:
                    sim = 1.0 - (dist / max_len)
                    # Require at least 70% character similarity to prevent false positives
                    if sim >= 0.70:
                        best_word_score = max(best_word_score, round(sim * 80.0, 2))
        total_score += best_word_score

    return total_score / len(q_words)


def expand_search_terms(query: str) -> List[str]:
    """Returns synonyms and expanded terms for a given search query."""
    q = query.lower().strip()
    terms = set([q])
    
    # Direct dictionary match
    if q in SYNONYM_DICTIONARY:
        terms.update(SYNONYM_DICTIONARY[q])
        
    # Word by word expansion
    words = q.split()
    for w in words:
        if w in SYNONYM_DICTIONARY:
            terms.update(SYNONYM_DICTIONARY[w])

    return list(terms)
