export interface MasterProduct {
  barcode: string
  name: string
  brand: string
  categorySlug: string
  categoryName: string
  mrp: number
  price: number
  unit: string
  imageUrl: string
}

export const MASTER_CATALOG: MasterProduct[] = [
  // Staples
  {
    barcode: "8901058002316",
    name: "Tata Salt (Iodized)",
    brand: "Tata",
    categorySlug: "atta-rice-dal",
    categoryName: "Atta, Rice & Dal",
    mrp: 28,
    price: 26,
    unit: "1 kg",
    imageUrl: "https://images.unsplash.com/photo-1627485605040-1c10d5010453?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901725181223",
    name: "Aashirvaad Shudh Chakki Atta",
    brand: "Aashirvaad",
    categorySlug: "atta-rice-dal",
    categoryName: "Atta, Rice & Dal",
    mrp: 65,
    price: 59,
    unit: "1 kg",
    imageUrl: "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8906007281404",
    name: "Fortune Mustard Oil",
    brand: "Fortune",
    categorySlug: "atta-rice-dal",
    categoryName: "Atta, Rice & Dal",
    mrp: 175,
    price: 155,
    unit: "1 L",
    imageUrl: "https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=300&auto=format&fit=crop&q=80"
  },
  // Snacks & Munchies
  {
    barcode: "8901058895628",
    name: "Maggi 2-Minute Masala Noodles",
    brand: "Nestlé Maggi",
    categorySlug: "snacks-munchies",
    categoryName: "Snacks & Munchies",
    mrp: 14,
    price: 13,
    unit: "70 g",
    imageUrl: "https://images.unsplash.com/photo-1612966608997-3000b21c45f7?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901109113010",
    name: "Parle-G Original Gluco Biscuits",
    brand: "Parle",
    categorySlug: "biscuits-cookies",
    categoryName: "Biscuits & Cookies",
    mrp: 10,
    price: 9.5,
    unit: "110 g",
    imageUrl: "https://images.unsplash.com/photo-1558961309-dbdf0f6b498f?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901063142144",
    name: "Britannia Marie Gold Biscuits",
    brand: "Britannia",
    categorySlug: "biscuits-cookies",
    categoryName: "Biscuits & Cookies",
    mrp: 35,
    price: 32,
    unit: "250 g",
    imageUrl: "https://images.unsplash.com/photo-1590080875515-8a3a8dc5735e?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901039016141",
    name: "Lays India's Magic Masala Chips",
    brand: "Lays",
    categorySlug: "snacks-munchies",
    categoryName: "Snacks & Munchies",
    mrp: 20,
    price: 19,
    unit: "48 g",
    imageUrl: "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300&auto=format&fit=crop&q=80"
  },
  // Beverages
  {
    barcode: "5449000000996",
    name: "Coca-Cola Original Taste Can",
    brand: "Coca-Cola",
    categorySlug: "beverages",
    categoryName: "Beverages",
    mrp: 40,
    price: 36,
    unit: "300 ml",
    imageUrl: "https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901491102834",
    name: "Real Fruit Power Mixed Fruit",
    brand: "Real",
    categorySlug: "beverages",
    categoryName: "Beverages",
    mrp: 125,
    price: 110,
    unit: "1 L",
    imageUrl: "https://images.unsplash.com/photo-1600271886742-f049cd451bba?w=300&auto=format&fit=crop&q=80"
  },
  // Dairy & Breakfast
  {
    barcode: "8901262010046",
    name: "Amul Butter (Pasteurised)",
    brand: "Amul",
    categorySlug: "dairy-breakfast",
    categoryName: "Dairy & Breakfast",
    mrp: 58,
    price: 56,
    unit: "100 g",
    imageUrl: "https://images.unsplash.com/photo-1589985270826-4b7bb135bc9d?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901262150346",
    name: "Amul Taaza Homogenised Milk",
    brand: "Amul",
    categorySlug: "dairy-breakfast",
    categoryName: "Dairy & Breakfast",
    mrp: 72,
    price: 70,
    unit: "1 L",
    imageUrl: "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300&auto=format&fit=crop&q=80"
  },
  // Household & Personal Care
  {
    barcode: "8901030753007",
    name: "Surf Excel Easy Wash Detergent",
    brand: "Surf Excel",
    categorySlug: "household-needs",
    categoryName: "Household Needs",
    mrp: 140,
    price: 128,
    unit: "1 kg",
    imageUrl: "https://images.unsplash.com/photo-1584622650111-993a426fbf0a?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901396328322",
    name: "Dettol Liquid Handwash Original",
    brand: "Dettol",
    categorySlug: "personal-care",
    categoryName: "Personal Care",
    mrp: 99,
    price: 89,
    unit: "200 ml",
    imageUrl: "https://images.unsplash.com/photo-1603055276395-ad4f44a83494?w=300&auto=format&fit=crop&q=80"
  },
  {
    barcode: "8901180005117",
    name: "Colgate Strong Teeth Toothpaste",
    brand: "Colgate",
    categorySlug: "personal-care",
    categoryName: "Personal Care",
    mrp: 110,
    price: 95,
    unit: "200 g",
    imageUrl: "https://images.unsplash.com/photo-1559591874-4b51874b5117?w=300&auto=format&fit=crop&q=80"
  }
]
