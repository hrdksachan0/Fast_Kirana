"""Bounded, editorial category curation using the existing settings table."""
import json
from services.campaign_config import CampaignValidationError, validate_image

KEY = 'featured_categories'
BADGES = ('', 'Featured', 'Seasonal', 'Everyday')
TINTS = ('auto', 'mint', 'cream', 'peach', 'sky', 'rose', 'lilac')

def validate_featured_categories(value):
    def fail(message):
        raise CampaignValidationError(message)
    if not isinstance(value, dict) or set(value) - {'version', 'enabled', 'title', 'items'}:
        fail('Invalid featured category configuration')
    if type(value.get('version')) is not int or value['version'] != 1:
        fail('version must be 1')
    enabled = value.get('enabled', True)
    title = value.get('title', 'Featured categories')
    items = value.get('items')
    if type(enabled) is not bool or not isinstance(title, str) or not 1 <= len(title.strip()) <= 80:
        fail('Invalid visibility or heading')
    if not isinstance(items, list) or len(items) > 6:
        fail('Choose up to six categories')
    result, ids = [], set()
    import re
    for item in items:
        if not isinstance(item, dict) or set(item) - {'categoryId', 'label', 'image', 'imageFit', 'badge', 'tint', 'enabled'}:
            fail('Invalid category item')
        category_id = item.get('categoryId')
        if not isinstance(category_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', category_id) or category_id in ids:
            fail('Category IDs must be unique and valid')
        ids.add(category_id)
        label, image = item.get('label', ''), item.get('image')
        badge, tint = item.get('badge', ''), item.get('tint', 'auto')
        visible, fit = item.get('enabled', True), item.get('imageFit', 'cover')
        if not isinstance(label, str) or len(label.strip()) > 60 or badge not in BADGES or tint not in TINTS or type(visible) is not bool or fit not in ('cover', 'contain'):
            fail('Invalid category display options')
        if image is not None:
            if not isinstance(image, str) or not image.startswith(('https://', '/')):
                fail('Use an HTTPS URL or absolute image path')
            validate_image(image)
        result.append({'categoryId': category_id, 'label': label.strip(), 'image': image, 'imageFit': fit, 'badge': badge, 'tint': tint, 'enabled': visible})
    return {'version': 1, 'enabled': enabled, 'title': title.strip(), 'items': result}

def stored_featured_categories(value):
    try:
        return validate_featured_categories(json.loads(value)) if value else None
    except (ValueError, TypeError, KeyError):
        return None

def is_grocery_parent(category):
    slug, name = category.slug.lower(), category.name.lower()
    return not category.parentId and not any(part in slug for part in ('restaurant', 'cafe', 'fastfood', 'fast-food-kitchen')) and not any(part in name for part in ('restaurant', 'cafe')) and not name.startswith('fast food')
