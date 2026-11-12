export interface ShowcaseProduct {
  id: string
  name: string
  unit: string
  price: number
  image: string
  category: string
}

export interface ShowcaseTheme {
  id: string
  name: string
  tag: string
  title: string
  subtitle: string
  shelf: string
  accent: string
  ink: string
  background: string
  soft: string
  hero: string
  layout: 'mosaic' | 'aisles' | 'offers' | 'boutique' | 'moments' | 'festival' | 'pairings'
  categories: { name: string; image: string; caption: string }[]
  products: ShowcaseProduct[]
}

const art = (name: string) => `/navratri/${name}.svg`
const product = (id: string, name: string, unit: string, price: number, image: string, category: string): ShowcaseProduct => ({ id, name, unit, price, image, category })

export const showcaseThemes: ShowcaseTheme[] = [
  {
    id: 'fresh', name: 'Fresh Market', tag: 'A little closer to nature', title: 'Good food.\nFresh beginnings.', subtitle: 'Fill your basket with everyday freshness.', shelf: 'Picked for your kitchen', accent: '#376743', ink: '#193b2a', background: '#f1f4df', soft: '#dde9c8', hero: '/navratri/fresh-market-hero.webp', layout: 'mosaic',
    categories: [
      { name: 'Vegetables', image: '/fruits_vegetables_category.webp', caption: 'From farm to fork' },
      { name: 'Fruits', image: art('summer-mango'), caption: 'A sweeter everyday' },
      { name: 'Dairy', image: '/dairy_breakfast_category.webp', caption: 'Your morning staples' },
    ],
    products: [product('veg', 'Fresh vegetable basket', '1 basket', 85, art('daily-vegetables'), 'Vegetables'), product('mango', 'Sweet mangoes', '500 g', 90, art('summer-mango'), 'Fruits'), product('milk', 'Fresh milk', '500 ml', 30, art('daily-milk'), 'Dairy'), product('coconut', 'Tender coconut', '1 piece', 55, art('summer-coconut'), 'Fruits')],
  },
  {
    id: 'daily', name: 'Daily Essentials', tag: 'The everyday edit', title: 'Little things.\nA sorted day.', subtitle: 'Your cupboard favourites, all in one place.', shelf: 'Restock your favourites', accent: '#38617b', ink: '#233d50', background: '#edf2f5', soft: '#dbe9ee', hero: '/navratri/daily-restock-hero.webp', layout: 'aisles',
    categories: [{ name: 'Breakfast', image: '/dairy_breakfast_category.webp', caption: 'Start well' }, { name: 'Pantry', image: '/atta_rice_dal_category.webp', caption: 'Kitchen staples' }, { name: 'Home care', image: '/household_category.webp', caption: 'Keep it fresh' }],
    products: [product('bread', 'Fresh bread loaf', '400 g', 40, art('daily-bread'), 'Breakfast'), product('rice', 'Everyday rice', '1 kg', 75, art('daily-rice'), 'Pantry'), product('oil', 'Cooking oil', '1 litre', 145, art('value-oil'), 'Pantry'), product('cleaner', 'Surface cleaner', '500 ml', 99, art('monsoon-cleaner'), 'Home care')],
  },
  {
    id: 'deals', name: 'Value Picks', tag: 'Small prices. Happy baskets.', title: 'Make room\nfor more value.', subtitle: 'Thoughtful picks for your monthly stock-up.', shelf: 'Pantry worth picking', accent: '#a33434', ink: '#5d2927', background: '#fff3d3', soft: '#f9df9d', hero: '/navratri/pack-value-hero.webp', layout: 'offers',
    categories: [{ name: 'Staples', image: art('value-atta'), caption: 'Stock the basics' }, { name: 'Cooking', image: art('value-oil'), caption: 'For every recipe' }, { name: 'Pulses', image: art('value-dal'), caption: 'Everyday goodness' }],
    products: [product('atta', 'Whole wheat atta', '5 kg', 249, art('value-atta'), 'Staples'), product('oil', 'Cooking oil', '1 litre', 145, art('value-oil'), 'Cooking'), product('dal', 'Yellow dal', '1 kg', 120, art('value-dal'), 'Pulses'), product('turmeric', 'Turmeric powder', '100 g', 35, art('value-turmeric'), 'Cooking')],
  },
  {
    id: 'gifts', name: 'Gifting Boutique', tag: 'Send a little happiness', title: 'Little gifts.\nBig feelings.', subtitle: 'For their big day. Or just because.', shelf: 'Made to make them smile', accent: '#963958', ink: '#59243c', background: '#fbedef', soft: '#f4d5de', hero: '/navratri/gifting-boutique-hero.webp', layout: 'boutique',
    categories: [{ name: 'Flowers', image: '/banners/puja-flowers.png', caption: 'Say it with blooms' }, { name: 'Chocolates', image: art('diwali-chocolates'), caption: 'Sweet little gestures' }, { name: 'Sweets', image: art('diwali-ladoo'), caption: 'Share some joy' }],
    products: [product('flowers', 'Flower collection', '1 bunch', 149, art('flowers-leaves'), 'Flowers'), product('chocolates', 'Chocolate gift box', '1 box', 299, art('diwali-chocolates'), 'Chocolates'), product('ladoo', 'Celebration ladoos', '250 g', 149, art('diwali-ladoo'), 'Sweets'), product('katli', 'Kaju katli', '250 g', 249, '/navratri/haldirams-kaju-katli-box.webp', 'Sweets')],
  },
  {
    id: 'snacks', name: 'Snack Time', tag: 'Your break has good taste', title: 'Big cravings.\nLittle breaks.', subtitle: 'Settle in. Your snack corner is right here.', shelf: 'Your next favourite bite', accent: '#7050a0', ink: '#392754', background: '#f1eafa', soft: '#e4d6f3', hero: '/navratri/movie-night-hero.webp', layout: 'moments',
    categories: [{ name: 'Movie night', image: '/snacks_munchies_category.webp', caption: 'Press play. Pass snacks.' }, { name: 'Chai break', image: '/bakery_biscuits_category.webp', caption: 'A perfectly paired pause' }, { name: 'Cool sips', image: '/beverages_category.webp', caption: 'Something refreshing' }],
    products: [product('chips', 'Crunchy potato chips', '100 g', 30, art('vrat-chips'), 'Movie night'), product('tea', 'Everyday tea', '250 g', 125, art('monsoon-tea'), 'Chai break'), product('juice', 'Fruit juice', '200 ml', 25, art('summer-juice'), 'Cool sips'), product('snacks', 'Snack mix', '150 g', 45, art('vrat-snacks'), 'Movie night')],
  },
  {
    id: 'festival', name: 'Festive Edit', tag: 'A home full of celebration', title: 'Light up\nthe little moments.', subtitle: 'Everything for a celebration to remember.', shelf: 'Bring the celebration home', accent: '#9b3f2b', ink: '#693324', background: '#fff0db', soft: '#f6d5a8', hero: art('diwali-celebration'), layout: 'festival',
    categories: [{ name: 'Puja', image: art('puja-thali'), caption: 'Sacred little rituals' }, { name: 'Decor', image: art('diwali-diyas'), caption: 'Let your home glow' }, { name: 'Sweets', image: art('diwali-ladoo'), caption: 'Happiness to share' }],
    products: [product('diyas', 'Traditional diyas', 'Set of 6', 99, art('diwali-diyas'), 'Decor'), product('thali', 'Puja thali', '1 set', 249, art('puja-thali'), 'Puja'), product('marigold', 'Marigold garland', '1 string', 49, art('diwali-marigold'), 'Decor'), product('ladoo', 'Festive ladoos', '250 g', 149, art('diwali-ladoo'), 'Sweets')],
  },
  {
    id: 'breakfast', name: 'Breakfast Club', tag: 'Start your day your way', title: 'Good mornings\nstart here.', subtitle: 'From your first sip to your last bite.', shelf: 'Build a better breakfast', accent: '#9c5b2e', ink: '#553524', background: '#fff1e3', soft: '#f6ddbe', hero: '/navratri/breakfast-club-hero.webp', layout: 'pairings',
    categories: [{ name: 'Toast & more', image: art('daily-bread'), caption: 'Golden little mornings' }, { name: 'Milk & dairy', image: art('daily-milk'), caption: 'Pour some goodness' }, { name: 'Tea time', image: art('monsoon-tea'), caption: 'Your first happy sip' }],
    products: [product('bread', 'Soft bread loaf', '400 g', 40, art('daily-bread'), 'Toast & more'), product('milk', 'Fresh milk', '500 ml', 30, art('daily-milk'), 'Milk & dairy'), product('tea', 'Breakfast tea', '250 g', 125, art('monsoon-tea'), 'Tea time'), product('lemon', 'Fresh lemons', '4 pieces', 25, art('summer-lemon'), 'Tea time')],
  },
]
