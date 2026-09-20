import 'package:fastkirana_flutter/data/models/product.dart';

class WebMenuSection {
  final String? id;
  final String tag;
  final List<String> matchTags;
  final String title;
  final String emoji;
  final String? imageUrl;
  final String description;

  const WebMenuSection({
    this.id,
    required this.tag,
    required this.matchTags,
    required this.title,
    required this.emoji,
    this.imageUrl,
    required this.description,
  });
}

// 1:1 Parity with www.fastkirana.in DEFAULT_CAFE_MENU_SECTIONS
const List<WebMenuSection> webCafeSections = [
  WebMenuSection(tag: 'hot-beverage', matchTags: ['hot-beverage', 'hot-coffee', 'hot coffee', 'tea', 'chai'], title: 'Brews & Tea', emoji: '☕', description: 'Chai, hot coffee, and fresh brewing mixes'),
  WebMenuSection(tag: 'hot-bite', matchTags: ['hot-bite', 'snacks', 'momos'], title: 'Quick Snacks', emoji: '🥟', description: 'Samosas, Momos, French Fries, and warm treats'),
  WebMenuSection(tag: 'sandwiches', matchTags: ['sandwiches', 'sandwich'], title: 'Sandwiches', emoji: '🥪', description: 'Freshly grilled sandwiches loaded with cheese, paneer, and veggies'),
  WebMenuSection(tag: 'burgers', matchTags: ['burgers', 'burger', 'veg-burger', 'cheese-burger', 'paneer-burger'], title: 'Burgers', emoji: '🍔', description: 'Juicy veg burgers, paneer burgers, and loaded cheese burgers'),
  WebMenuSection(tag: 'frankie-rolls', matchTags: ['frankie-rolls', 'frankie rolls', 'frankie-roll', 'frankie roll', 'rolls', 'roll', 'kathi roll', 'kathi-roll'], title: 'Rolls & Frankie', emoji: '🌯', description: 'Fresh rolls stuffed with paneer, cheese, and veg patties'),
  WebMenuSection(tag: 'garlic-bread', matchTags: ['garlic-bread', 'garlic bread', 'garlic-breads'], title: 'Garlic Bread', emoji: '🧄', description: 'Loaded garlic breads with corn, paneer, cheese & mix veg'),
  WebMenuSection(tag: 'pizza', matchTags: ['pizza', 'pizzas'], title: 'Pizzas', emoji: '🍕', description: 'Loaded pizzas with fresh toppings and melted cheese'),
  WebMenuSection(tag: 'pav-bhaji', matchTags: ['pav-bhaji', 'pav bhaji', 'pavbhaji'], title: 'Pav Bhaji', emoji: '🫕', description: 'Butter Pav Bhaji, Paneer Pav Bhaji & Extra Pav'),
  WebMenuSection(tag: 'chinese', matchTags: ['chinese', 'chinese-cuisine', 'chinese cuisine'], title: 'Chinese', emoji: '🥡', description: 'Momos, noodles, fried dishes & sauces'),
  WebMenuSection(tag: 'italian-pasta', matchTags: ['italian-pasta', 'italian-pastas', "italian pasta's", 'pasta'], title: 'Pastas', emoji: '🍝', description: 'Fresh penne tossed in aromatic red & white sauces'),
  WebMenuSection(tag: 'south-indian', matchTags: ['south-indian', 'south indian', 'dosa'], title: 'South Indian', emoji: '🍛', description: 'Dosa, Idli, Vada, Uttapam & more'),
  WebMenuSection(tag: 'bombay-bites', matchTags: ['bombay-bites', 'bombay bites', 'bombay-bite', 'bombay bite'], title: 'Bombay Bites', emoji: '🥪', description: 'Vada Pav, special Bombay Masala Toast, and street snacks'),
  WebMenuSection(tag: 'rice-dishes', matchTags: ['rice-dishes', 'rice dishes', 'rice-dish', 'rice dish', 'biryani', 'pulav'], title: 'Rice & Bowls', emoji: '🍚', description: 'Flavourful biryani, fried rice, and combos'),
  WebMenuSection(tag: 'shakes', matchTags: ['shakes', 'shake', 'milkshake', 'milkshakes'], title: 'Shakes', emoji: '🥤', description: 'Creamy strawberry, chocolate, and Oreo shakes'),
  WebMenuSection(tag: 'mocktails', matchTags: ['mocktails', 'mocktail', 'coolers', 'cooler', 'mojito'], title: 'Mocktails', emoji: '🍹', description: 'Iced coolers, Virgin Mojito, and summer drinks'),
  WebMenuSection(tag: 'cold-coffee', matchTags: ['cold-coffee', 'cold coffee', 'iced coffee', 'iced-coffee'], title: 'Cold Coffee', emoji: '🧋', description: 'Classic cold brews, hazelnut cold coffee & iced sips'),
  WebMenuSection(tag: 'bakery', matchTags: ['bakery', 'bakery-biscuits', 'cake', 'cakes'], title: 'Bakery', emoji: '🎂', description: 'Freshly baked cakes, pastries, and sweet treats'),
  WebMenuSection(tag: 'chilled', matchTags: ['chilled', 'cold-drink', 'beverages', 'beverage', 'drinks', 'drink'], title: 'Cold Drinks', emoji: '🥤', description: 'Carbonated soft drinks and cold energy boosts'),
  WebMenuSection(tag: 'desserts', matchTags: ['desserts', 'ice-cream', 'ice cream', 'kulfi', 'dessert', 'sweet'], title: 'Desserts', emoji: '🍦', description: 'Chilled premium ice creams, kulfis, and desserts'),
];

// 1:1 Parity with www.fastkirana.in DEFAULT_RESTAURANT_MENU_SECTIONS (Wedson, Bal Udyan)
const List<WebMenuSection> webRestaurantSections = [
  WebMenuSection(
    tag: 'main-course',
    matchTags: ['north-indian', 'curry', 'dal-makhani', 'paneer-butter-masala', 'paneer', 'main-course', 'dal'],
    title: 'Curries & Gravies',
    emoji: '🥘',
    description: 'Rich paneer butter masala, creamy dal makhani, and Special Kadhai Gravies',
  ),
  WebMenuSection(
    tag: 'roti-naan-breads',
    matchTags: ['roti-naan-kulcha', 'roti', 'naan', 'kulcha', 'breads', 'paratha-bread'],
    title: 'Rotis & Naans',
    emoji: '🫓',
    description: 'Butter Naan, Garlic Naan, Tandoori Roti, Missi Roti & Stuffed Kulchas',
  ),
  WebMenuSection(
    tag: 'starters-tandoori',
    matchTags: ['special-starters', 'tandoori-nawab-nawab', 'starter', 'starters', 'kebabs', 'tikka', 'chaap'],
    title: 'Starters & Tandoori',
    emoji: '🍢',
    description: 'Soya Malai Chaap, Paneer Tikka, Veg Seekh Kebab & Dahi Kebab',
  ),
  WebMenuSection(
    tag: 'biryani-rice',
    matchTags: ['biryani-rice', 'biryani', 'pulav', 'fried-rice', 'jeera-rice', 'basmati-rice-/-biryani'],
    title: 'Biryani & Rice',
    emoji: '🍚',
    description: 'Aromatic basmati veg biryanis, paneer pulavs & loaded fried rice bowls',
  ),
  WebMenuSection(
    tag: 'pizzas-burgers',
    matchTags: ['pizza', 'burger', 'burgers', 'pizzas', 'sandwich'],
    title: 'Pizza & Burgers',
    emoji: '🍕',
    description: 'Fresh baked pizzas, loaded veggie burgers & grilled sandwiches',
  ),
  WebMenuSection(
    tag: 'chinese-soups',
    matchTags: ['chinese', 'noodles', 'manchurian', 'chilli-paneer', 'spring-rolls', 'soup', 'pasta'],
    title: 'Chinese & Soups',
    emoji: '🥡',
    description: 'Stir-fried noodles, saucy veg manchurian, hot soups & pastas',
  ),
  WebMenuSection(
    tag: 'breakfast',
    matchTags: ['breakfast', 'paratha', 'poori', 'chole-bhature', 'nashta', 'poha'],
    title: 'Breakfast',
    emoji: '🍳',
    description: 'Chole Bhature, Parathas, Poori and morning favorites',
  ),
  WebMenuSection(
    tag: 'shakes-beverages',
    matchTags: ['shake', 'shakes', 'beverage', 'beverages', 'drinks', 'drink', 'cold-drink', 'cold-drinks', 'mocktail', 'coffee', 'chilled'],
    title: 'Shakes & Drinks',
    emoji: '🥤',
    description: 'Chocolate, Oreo, Strawberry thick shakes & refreshing coolers',
  ),
  WebMenuSection(
    tag: 'desserts',
    matchTags: ['desserts', 'gulab-jamun', 'ice-cream', 'ice cream', 'kheer', 'dessert', 'sweet', 'sweets'],
    title: 'Desserts & Sweet Sips',
    emoji: '🍨',
    description: 'Hot gulab jamuns, premium ice creams, and traditional sweets',
  ),
];

String? getCategoryAssetImage(String tag) {
  if (tag.isEmpty) return null;
  final clean = tag.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  const mapping = <String, String>{
    'all': 'assets/categories/cafe_all_menu_category.webp',
    'hotbeverage': 'assets/categories/cafe_brews_category.webp',
    'hotbeverages': 'assets/categories/cafe_brews_category.webp',
    'brews': 'assets/categories/cafe_brews_category.webp',
    'brew': 'assets/categories/cafe_brews_category.webp',
    'tea': 'assets/categories/cafe_brews_category.webp',
    'chai': 'assets/categories/cafe_brews_category.webp',
    'hotbite': 'assets/categories/cafe_snacks_category.webp',
    'hotbites': 'assets/categories/cafe_snacks_category.webp',
    'snack': 'assets/categories/cafe_snacks_category.webp',
    'snacks': 'assets/categories/cafe_snacks_category.webp',
    'quickbites': 'assets/categories/cafe_snacks_category.webp',
    'momos': 'assets/categories/cafe_snacks_category.webp',
    'momo': 'assets/categories/cafe_snacks_category.webp',
    'fries': 'assets/categories/cafe_snacks_category.webp',
    'sandwich': 'assets/categories/cafe_sandwiches_category.webp',
    'sandwiches': 'assets/categories/cafe_sandwiches_category.webp',
    'burger': 'assets/categories/cafe_burgers_category.webp',
    'burgers': 'assets/categories/cafe_burgers_category.webp',
    'frankierolls': 'assets/categories/cafe_rolls_category.webp',
    'frankieroll': 'assets/categories/cafe_rolls_category.webp',
    'rolls': 'assets/categories/cafe_rolls_category.webp',
    'roll': 'assets/categories/cafe_rolls_category.webp',
    'garlicbread': 'assets/categories/cafe_garlic_bread_category.webp',
    'garlicbreads': 'assets/categories/cafe_garlic_bread_category.webp',
    'garlic': 'assets/categories/cafe_garlic_bread_category.webp',
    'bread': 'assets/categories/cafe_garlic_bread_category.webp',
    'breads': 'assets/categories/cafe_garlic_bread_category.webp',
    'pizza': 'assets/categories/cafe_pizzas_category.webp',
    'pizzas': 'assets/categories/cafe_pizzas_category.webp',
    'pavbhaji': 'assets/categories/cafe_pav_bhaji_category.webp',
    'pav': 'assets/categories/cafe_pav_bhaji_category.webp',
    'bhaji': 'assets/categories/cafe_pav_bhaji_category.webp',
    'chinese': 'assets/categories/cafe_chinese_category.webp',
    'chinesecuisine': 'assets/categories/cafe_chinese_category.webp',
    'noodles': 'assets/categories/cafe_chinese_category.webp',
    'noodle': 'assets/categories/cafe_chinese_category.webp',
    'chowmein': 'assets/categories/cafe_chinese_category.webp',
    'pasta': 'assets/categories/cafe_pastas_category.webp',
    'pastas': 'assets/categories/cafe_pastas_category.webp',
    'italianpasta': 'assets/categories/cafe_pastas_category.webp',
    'southindian': 'assets/categories/cafe_south_indian_category.webp',
    'dosa': 'assets/categories/cafe_south_indian_category.webp',
    'idli': 'assets/categories/cafe_south_indian_category.webp',
    'vada': 'assets/categories/cafe_south_indian_category.webp',
    'bombaybites': 'assets/categories/cafe_bombay_bites_category.webp',
    'vadapav': 'assets/categories/cafe_bombay_bites_category.webp',
    'toast': 'assets/categories/cafe_bombay_bites_category.webp',
    'ricedishes': 'assets/categories/cafe_rice_category.webp',
    'rice': 'assets/categories/cafe_rice_category.webp',
    'biryani': 'assets/categories/cafe_rice_category.webp',
    'pulav': 'assets/categories/cafe_rice_category.webp',
    'friedrice': 'assets/categories/cafe_rice_category.webp',
    'shakes': 'assets/categories/cafe_shakes_category.webp',
    'shake': 'assets/categories/cafe_shakes_category.webp',
    'milkshake': 'assets/categories/cafe_shakes_category.webp',
    'milkshakes': 'assets/categories/cafe_shakes_category.webp',
    'mocktails': 'assets/categories/cafe_mocktails_category.webp',
    'mocktail': 'assets/categories/cafe_mocktails_category.webp',
    'mojito': 'assets/categories/cafe_mocktails_category.webp',
    'cooler': 'assets/categories/cafe_mocktails_category.webp',
    'coolers': 'assets/categories/cafe_mocktails_category.webp',
    'coldcoffee': 'assets/categories/cafe_cold_coffee_category.webp',
    'icedcoffee': 'assets/categories/cafe_cold_coffee_category.webp',
    'bakery': 'assets/categories/bakery_category.webp',
    'cake': 'assets/categories/bakery_category.webp',
    'cakes': 'assets/categories/bakery_category.webp',
    'pastry': 'assets/categories/bakery_category.webp',
    'chilled': 'assets/categories/cafe_cold_drinks_category.webp',
    'colddrink': 'assets/categories/cafe_cold_drinks_category.webp',
    'colddrinks': 'assets/categories/cafe_cold_drinks_category.webp',
    'beverages': 'assets/categories/cafe_cold_drinks_category.webp',
    'beverage': 'assets/categories/cafe_cold_drinks_category.webp',
    'chilleddrinks': 'assets/categories/cafe_cold_drinks_category.webp',
    'drinks': 'assets/categories/cafe_cold_drinks_category.webp',
    'drink': 'assets/categories/cafe_cold_drinks_category.webp',
    'lassi': 'assets/categories/cafe_shakes_category.webp',
    'desserts': 'assets/categories/ice_cream_category.webp',
    'dessert': 'assets/categories/ice_cream_category.webp',
    'icecream': 'assets/categories/ice_cream_category.webp',
    'icecreams': 'assets/categories/ice_cream_category.webp',
  };
  return mapping[clean];
}

class RenderedCategory {
  final String tag;
  final String title;
  final String emoji;
  final String? imageUrl;
  final List<Product> products;

  const RenderedCategory({
    required this.tag,
    required this.title,
    required this.emoji,
    this.imageUrl,
    required this.products,
  });
}
