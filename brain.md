# FastKirana — Project Brain

> Last updated: 2026-08-09

## 1. Project Overview

FastKirana is a full-stack grocery/retail delivery platform built with Next.js 14 and Prisma. It supports grocery stores, dark stores, and restaurant ordering with real-time order tracking, delivery management, and admin dashboards.

## 2. Technology Stack

| Layer | Tech |
|-------|------|
| Frontend | Next.js 14 (App Router), React Server Components |
| Backend | Next.js API Routes (tRPC-free, direct route handlers) |
| Database | PostgreSQL via Prisma ORM |
| Auth | NextAuth v5 (Credentials + OTP) |
| UI | Tailwind CSS v4, shadcn/ui, Framer Motion |
| State | Zustand (UI store), React Context (cart) |
| Realtime | SSE (Server-Sent Events) for live orders |
| Payments | Paytm (mock + real) |

## 3. Project Structure

```
src/
├── app/
│   ├── account/                    # Customer account pages
│   │   ├── dashboard/              # Main account dashboard (orders, addresses, profile)
│   │   ├── orders/[id]/            # Order detail page
│   │   └── wishlist/               # Wishlist page
│   ├── admin/                      # Admin dashboard
│   │   ├── dashboard/              # Admin main dashboard
│   │   └── orders/                 # Order management
│   ├── api/                        # API routes
│   │   ├── auth/                   # Authentication (OTP + credentials)
│   │   ├── wishlist/               # Wishlist API (GET/POST/DELETE)
│   │   ├── cart/                   # Cart management
│   │   ├── products/               # Product APIs
│   │   ├── orders/                 # Order lifecycle
│   │   └── admin/                  # Admin APIs
│   ├── checkout/                   # Checkout flow
│   ├── search/                     # Search results page
│   ├── product/[slug]/             # Product detail
│   └── ...                         # Public pages
├── components/
│   ├── account/                    # Account dashboard components
│   ├── admin/                      # Admin dashboard components
│   ├── home/                       # Homepage components
│   ├── product/                    # Product card, image, variants
│   ├── search/                     # Search filters
│   ├── providers/                  # Context providers (live stock, SSE)
│   ├── shared/                     # Reusable components (location picker, search overlay)
│   ├── layout/                     # Navbar, footer, sidebar
│   └── ui/                         # shadcn/ui primitives
├── hooks/
│   ├── use-cart.ts                 # Cart state management
│   └── use-push-notification.ts    # Push notifications
├── lib/
│   ├── prisma.ts                   # Prisma client singleton
│   ├── utils.ts                    # Utilities (formatPrice, sortProducts)
│   ├── constants.ts                # App-wide constants
│   └── ...
├── stores/
│   ├── cart-store.ts               # Zustand: cart state
│   └── ui-store.ts                 # Zustand: store hours, categories, location
├── types/
│   └── index.ts                    # TypeScript types
└── auth.ts                         # NextAuth configuration
```

## 4. Database Schema — Key Models

```
User ──┬── Address (1:N)
       ├── Cart (1:1)
       │   └── CartItem (1:N)
       ├── Order (1:N)
       │   └── OrderItem (1:N)
       ├── Review (1:N)
       ├── PushSubscription (1:N)
       ├── WishlistItem (1:N)  ★
       └── DeliveryOrders (as rider)
Category (1:N) → Product (1:N)
Product ──┬── ProductImage (1:N)
          ├── CartItem
          ├── OrderItem
          ├── Review
          ├── StockAlert
          ├── PriceHistory
          ├── ProductBatch
          └── WishlistItem  ★
```

## 5. Key Features & Their Status

| Feature | Status | Notes |
|---------|--------|-------|
| OTP Login (phone + email) | ✅ Done | Works with test OTP in dev |
| Product browsing | ✅ Done | Category tabs, search, filters |
| Cart management | ✅ Done | Add, remove, update quantity |
| Checkout flow | ✅ Done | Address, payment, order placement |
| Live order tracking (SSE) | ✅ Done | Real-time status updates |
| Delivery assignment | ✅ Done | Auto + manual assignment |
| Admin dashboard | ✅ Done | Products, orders, users, analytics |
| Product reviews | ✅ Done | Display on product pages |
| Error boundaries + loading | ✅ Done | App-level error + loading UI |
| SEO meta tags | ✅ Done | OpenGraph, structured data |
| Accessibility (ARIA) | ⚠️ Partial | Tab switcher + modals done |
| Reorder button | ✅ Done | Fixed in order history |
| **Wishlist** | ✅ Done | DB + API + page + product card heart button |
| **Search refinement** | ✅ Done | Category, price range, sort, in-stock filters |
| Accessibility (ARIA) | ✅ Done | Added to wishlist, search filters, product cards |
| Product card cleanup | ✅ Done | Moved state to proper locations, heart button added |

## 6. Important Patterns & Conventions

### Cart API (addItem)
```typescript
addItem({
  id: string,           // product ID
  name: string,
  slug: string,
  imageUrl: string | null,
  mrp: number,          // MRP price
  price: number,        // selling price
  discount: number,
  unit: string,         // "1 kg", "500 ml", etc.
  stock: number,
  isAvailable: boolean,
  tags: string[],
  category?: { id, name, slug },  // optional
})
```

### Order Item Structure
```typescript
{
  id: string,           // orderItem ID
  productId: string,
  name: string,
  imageUrl: string,
  price: number,
  mrp?: number,
  quantity: number,
  unit?: string,
}
```

### Product Type Detection
```typescript
const productType = getProductType(product) // 'GROCERY' | 'CAFE' | 'RESTAURANT'
```

## 7. UI Component Patterns

- All product pages use shadcn/ui components
- Tailwind v4 CSS variables for theming
- Dark mode via `dark:` prefix classes
- Mobile-first: `min-[375px]:` prefixes used throughout
- Animations: Framer Motion for transitions
- Icons: Lucide React

## 8. Store Configuration (Zustand)

### ui-store.ts (main store)
- `groceryMartOpen`, `cafeOpen`, `restaurantOpen` — toggle store sections
- `categoryStatus` — per-category availability
- `selectedLocation` — delivery address
- `setActiveVariantProduct` — variant selector state
- `toggleCart`, `isSearchOpen` — overlay controls

### cart-store.ts
- `items` — cart items array
- `addItem`, `removeItem`, `updateQuantity`, `clearCart`
- `getTotalItems()`, `getSubtotal()`

## 9. API Route Patterns

- All API routes use `NextRequest`/`NextResponse` from `next/server`
- Auth checks via `auth()` from `@/auth`
- Wishlist API: GET `/api/wishlist`, POST `/api/wishlist`, DELETE `/api/wishlist`
- Cart API: GET `/api/cart`, POST `/api/cart`, PATCH `/api/cart`
- Orders: `/api/orders` (CRUD + status updates)

## 10. Development Notes

- Run with `npm run dev` on port 3000
- Test OTP: `123456` for any phone number
- Prisma Studio: `npx prisma studio`
- Admin credentials: check `.env` file
- Mobile testing: use Chrome DevTools device emulation
