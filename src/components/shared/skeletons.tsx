'use client'

import { Skeleton } from '@/components/ui/skeleton'

// 1. Single Product Card Skeleton (used in storefront, search, category, etc.)
export function ProductCardSkeleton() {
  return (
    <div className="bg-card border border-border p-3.5 rounded-2xl shadow-sm flex flex-col justify-between space-y-3 h-full animate-pulse">
      {/* Product Image placeholder */}
      <div className="relative aspect-square w-full rounded-xl bg-muted/50 overflow-hidden" />
      
      {/* Product Details */}
      <div className="space-y-2 flex-1">
        {/* Name */}
        <div className="h-4 bg-muted/65 rounded w-5/6" />
        {/* Unit */}
        <div className="h-3 bg-muted/50 rounded w-1/3" />
        
        {/* Price & Add button row */}
        <div className="flex justify-between items-center pt-2">
          <div className="space-y-1">
            {/* Price */}
            <div className="h-4 bg-muted/70 rounded w-12" />
            {/* MRP */}
            <div className="h-3 bg-muted/40 rounded w-8" />
          </div>
          {/* Add button */}
          <div className="h-8 w-16 bg-muted/60 rounded-lg" />
        </div>
      </div>
    </div>
  )
}

// 2. Circular Category Item Skeleton
export function CategoryItemSkeleton() {
  return (
    <div className="flex flex-col items-center flex-shrink-0 animate-pulse w-[70px]">
      <div className="w-[66px] h-[66px] md:w-16 md:h-16 rounded-full bg-muted/50" />
      <div className="h-2.5 bg-muted/50 rounded w-12 mt-2" />
    </div>
  )
}

// 3. Homepage Skeleton
export function HomepageSkeleton() {
  return (
    <div className="container mx-auto px-4 pt-3 pb-0 space-y-1.5 md:space-y-8 max-w-7xl animate-pulse">
      {/* Shop Categories Circular List / Grid */}
      <div className="py-2 md:py-6">
        {/* Mobile: Horizontal scrollable sliding list */}
        <div className="flex gap-4.5 overflow-x-auto pb-3.5 pt-1.5 scrollbar-none md:hidden px-2 select-none">
          {Array.from({ length: 8 }).map((_, i) => (
            <CategoryItemSkeleton key={i} />
          ))}
        </div>
        
        {/* Desktop: Grid layout */}
        <div className="hidden md:grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 lg:grid-cols-9 gap-4 py-2">
          {Array.from({ length: 9 }).map((_, i) => (
            <div key={i} className="flex flex-col items-center p-3">
              <div className="w-16 h-16 rounded-2xl bg-muted/50" />
              <div className="h-3 bg-muted/45 rounded w-14 mt-2" />
              <div className="h-2.5 bg-muted/30 rounded w-8 mt-1" />
            </div>
          ))}
        </div>
      </div>

      {/* Hero Banner Skeleton */}
      <div className="w-full h-[130px] min-[375px]:h-[135px] sm:h-[185px] md:h-[260px] rounded-2xl md:rounded-3xl bg-muted/40" />

      {/* Speed Strip Skeleton */}
      <div className="py-1.5 md:py-3">
        <div className="w-full h-8 min-[375px]:h-9 md:h-[52px] rounded-xl bg-muted/30" />
      </div>

      {/* Cafe Section Skeleton */}
      <div className="space-y-4">
        <div className="w-full h-[120px] sm:h-[140px] md:h-[160px] rounded-3xl bg-muted/40" />
        
        <div className="flex items-center justify-between px-1">
          <div className="h-3.5 w-24 bg-muted/50 rounded" />
          <div className="h-3 w-16 bg-muted/40 rounded" />
        </div>

        <div className="flex gap-4.5 overflow-x-auto pb-3.5 pt-1.5 scrollbar-none px-2 select-none">
          {Array.from({ length: 8 }).map((_, i) => (
            <div key={i} className="w-[70px] shrink-0 flex flex-col items-center">
              <div className="w-[64px] h-[64px] rounded-full bg-muted/50" />
              <div className="h-2 bg-muted/40 rounded w-10 mt-2" />
            </div>
          ))}
        </div>
      </div>

      {/* Deals & Curations Hub Skeleton */}
      <div className="relative py-4 md:py-8 space-y-6 px-1 transition-all duration-500">
        {/* Hub Title & Subtitle */}
        <div className="px-1 space-y-1.5">
          <div className="h-6 bg-muted/65 rounded w-44" />
          <div className="h-3.5 bg-muted/40 rounded w-60" />
        </div>

        {/* Curation Tab Bar circles */}
        <div className="flex items-center gap-6 sm:gap-10 overflow-x-auto pb-3.5 pt-2 select-none w-full justify-start sm:justify-center px-1">
          {Array.from({ length: 5 }).map((_, i) => (
            <div key={i} className="flex flex-col items-center gap-2 shrink-0">
              <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-full bg-muted/50" />
              <div className="h-2.5 bg-muted/45 rounded w-14 mt-1" />
            </div>
          ))}
        </div>

        {/* Grouped Products scrollable lists */}
        <div className="space-y-6">
          {Array.from({ length: 2 }).map((_, gIdx) => (
            <div key={gIdx} className="space-y-2.5">
              {/* Category subheader */}
              <div className="flex items-center justify-between px-1">
                <div className="flex items-center gap-2">
                  <div className="h-5 bg-muted/65 rounded w-32" />
                  <div className="h-4 w-12 bg-muted/45 rounded-full" />
                </div>
                <div className="h-4 bg-muted/40 rounded w-14" />
              </div>
              
              {/* Category Products Horizontal Snap Track */}
              <div className="flex gap-2.5 md:gap-4 overflow-x-auto pb-2 md:pb-4">
                {Array.from({ length: 4 }).map((_, pIdx) => (
                  <div key={pIdx} className="w-[130px] min-[375px]:w-[140px] sm:w-[150px] md:w-[190px] flex-shrink-0">
                    <div className="bg-card border border-border/50 p-2.5 rounded-xl space-y-2.5 h-[200px] min-[375px]:h-[220px] sm:h-[240px] md:h-[280px]">
                      <div className="aspect-square w-full rounded-lg bg-muted/40" />
                      <div className="h-3 bg-muted/50 rounded w-5/6" />
                      <div className="h-2.5 bg-muted/30 rounded w-1/2" />
                      <div className="flex justify-between items-center pt-1">
                        <div className="h-3 bg-muted/60 rounded w-8" />
                        <div className="h-6 w-12 bg-muted/55 rounded" />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

// 4. Category Details Page Skeleton
export function CategorySkeleton() {
  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl animate-pulse">
      <div className="flex flex-col md:flex-row gap-6">
        {/* Desktop Left Sidebar: Categories Navigation */}
        <aside className="hidden md:block w-64 flex-shrink-0 border border-border bg-card p-4 rounded-2xl h-fit space-y-4">
          <div className="h-5 bg-muted/70 rounded w-28 mb-4 px-2" />
          <div className="space-y-2">
            {Array.from({ length: 8 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3 w-full px-3 py-2.5 rounded-xl border border-transparent bg-muted/20">
                <div className="h-5 w-5 rounded bg-muted/50" />
                <div className="h-3 bg-muted/60 rounded w-28" />
                <div className="h-4 w-6 rounded bg-muted/50 ml-auto" />
              </div>
            ))}
          </div>
        </aside>

        {/* Right Section: Header and Product Grid */}
        <main className="flex-grow space-y-6">
          {/* Mobile Category Horizontal Scrollbar */}
          <div className="md:hidden overflow-x-auto flex gap-2 pb-2 scrollbar-hide">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="h-7 w-24 rounded-full bg-muted/30 border border-border/40 shrink-0" />
            ))}
          </div>

          {/* Category Header */}
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 border-b border-border/60 pb-4">
            <div className="flex items-center gap-3">
              <div className="h-10 w-10 rounded bg-muted/50" />
              <div className="space-y-1.5">
                <div className="h-5 bg-muted/65 rounded w-36" />
                <div className="h-3 bg-muted/40 rounded w-28" />
              </div>
            </div>
            <div className="h-7 w-48 bg-muted/40 rounded-xl" />
          </div>

          {/* Search Bar placeholder */}
          <div className="w-full max-w-md h-9 bg-muted/30 border border-border/60 rounded-xl" />

          {/* Products Catalog Grid */}
          <div className="grid grid-cols-2 min-[375px]:grid-cols-3 sm:grid-cols-3 lg:grid-cols-4 gap-2 md:gap-4">
            {Array.from({ length: 8 }).map((_, i) => (
              <ProductCardSkeleton key={i} />
            ))}
          </div>
        </main>
      </div>
    </div>
  )
}

// 5. Product Detail Page Skeleton
export function ProductDetailSkeleton() {
  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl space-y-6 md:space-y-10 animate-pulse">
      {/* Breadcrumbs */}
      <div className="h-3.5 bg-muted/40 rounded w-64 px-1" />

      {/* Main product details section */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-8 lg:gap-12 bg-card border border-border p-3.5 min-[375px]:p-5 md:p-6 rounded-2xl shadow-sm">
        {/* Left Column: Image placeholder */}
        <div className="aspect-square w-full rounded-2xl border border-border/40 bg-muted/20" />

        {/* Right Column: Information & Actions */}
        <div className="flex flex-col justify-between space-y-4 md:space-y-6">
          <div className="space-y-3.5 md:space-y-4">
            {/* Category tag */}
            <div className="h-5 bg-muted/55 rounded-full w-24" />
            {/* Name */}
            <div className="h-7 bg-muted/65 rounded w-4/5" />
            
            {/* Unit & Ratings */}
            <div className="flex items-center gap-4">
              <div className="h-6 bg-muted/40 rounded w-16" />
              <div className="h-6 bg-muted/40 rounded w-32" />
            </div>

            {/* Price block */}
            <div className="flex items-baseline gap-3 pt-2">
              <div className="h-8 bg-muted/75 rounded w-24" />
              <div className="h-6 bg-muted/40 rounded w-16" />
            </div>

            {/* Delivery Banner */}
            <div className="h-11 bg-muted/30 border border-border/40 rounded-xl w-full" />

            {/* Verified Badge placeholder */}
            <div className="h-20 bg-muted/25 border border-border/45 rounded-xl w-full" />

            {/* Add button placeholder */}
            <div className="h-10 bg-muted/50 rounded-xl w-32 pt-2" />
          </div>

          {/* Accordions */}
          <div className="pt-4 border-t border-border/40 space-y-2">
            <div className="h-9 bg-muted/20 border-b border-border/40 rounded w-full" />
            <div className="h-9 bg-muted/20 border-b border-border/40 rounded w-full" />
          </div>
        </div>
      </div>

      {/* Related Products Section */}
      <div className="space-y-3">
        <div className="h-5 bg-muted/65 rounded w-36" />
        <div className="grid grid-cols-2 min-[375px]:grid-cols-3 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4">
          {Array.from({ length: 6 }).map((_, i) => (
            <ProductCardSkeleton key={i} />
          ))}
        </div>
      </div>
    </div>
  )
}

// 6. Search Results Page Skeleton
export function SearchSkeleton() {
  return (
    <div className="container mx-auto px-2 min-[375px]:px-4 py-4 min-[375px]:py-6 max-w-7xl space-y-6 animate-pulse">
      {/* Search Header */}
      <div className="border-b border-border/60 pb-4 space-y-1.5">
        <div className="h-6 bg-muted/65 rounded w-72" />
        <div className="h-3.5 bg-muted/40 rounded w-48" />
      </div>

      {/* Product Results Grid */}
      <div className="grid grid-cols-2 min-[375px]:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-2 md:gap-4 px-1">
        {Array.from({ length: 12 }).map((_, i) => (
          <ProductCardSkeleton key={i} />
        ))}
      </div>
    </div>
  )
}

// 7. Cafe Storefront Skeleton
export function CafeSkeleton() {
  return (
    <div className="container mx-auto px-4 py-4 sm:py-6 max-w-5xl space-y-4 sm:space-y-6 animate-pulse">
      {/* Cafe Header Banner */}
      <div className="relative overflow-hidden rounded-2xl bg-muted/40 h-28 sm:h-36" />

      {/* Mobile Sticky categories bar */}
      <div className="md:hidden flex gap-2 pb-2 overflow-x-auto scrollbar-hide border-b border-border/60 py-2">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="h-7 w-20 rounded-full bg-muted/30 border border-border/40 shrink-0" />
        ))}
      </div>

      {/* Split layout: Sidebar + main menu list */}
      <div className="flex gap-8 items-start">
        {/* Desktop Vertical Sidebar */}
        <aside className="hidden md:block w-64 shrink-0 border-r border-border/40 space-y-2 pr-2">
          <div className="h-3.5 bg-muted/65 rounded w-24 mb-4" />
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="flex justify-between items-center px-3 py-2.5 rounded-xl bg-muted/20">
              <div className="h-3 bg-muted/60 rounded w-28" />
              <div className="h-3.5 w-6 rounded bg-muted/40" />
            </div>
          ))}
        </aside>

        {/* Categories Main Content Area */}
        <div className="flex-grow space-y-10">
          {Array.from({ length: 3 }).map((_, secIdx) => (
            <section key={secIdx} className="space-y-4">
              <div className="flex items-center gap-3">
                <div className="h-5 bg-muted/65 rounded w-40" />
                <div className="h-3 bg-muted/40 rounded w-52" />
              </div>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {Array.from({ length: 4 }).map((_, cardIdx) => (
                  <ProductCardSkeleton key={cardIdx} />
                ))}
              </div>
            </section>
          ))}
        </div>
      </div>
    </div>
  )
}

// 8. Cart Page Skeleton
export function CartSkeleton() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl animate-pulse">
      <div className="h-7 bg-muted/65 rounded w-40 mb-6" />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 items-start">
        {/* Left: Cart Items List */}
        <div className="lg:col-span-2 space-y-4">
          <div className="bg-card border border-border p-4 rounded-2xl shadow-sm space-y-4">
            {Array.from({ length: 3 }).map((_, i) => (
              <div key={i} className="flex gap-4 items-center py-4 border-b border-border/50 last:border-0">
                {/* Image */}
                <div className="h-16 w-16 rounded-xl bg-muted/40 shrink-0" />
                {/* Text Details */}
                <div className="flex-1 space-y-2 min-w-0">
                  <div className="h-4 bg-muted/60 rounded w-3/4" />
                  <div className="h-3 bg-muted/40 rounded w-16" />
                </div>
                {/* Quantity adjuster */}
                <div className="h-8 w-20 bg-muted/50 rounded-lg shrink-0" />
                {/* Price */}
                <div className="h-4 bg-muted/70 rounded w-12 text-right shrink-0" />
              </div>
            ))}
          </div>
        </div>

        {/* Right: Checkout summary details */}
        <div className="space-y-6">
          <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-4">
            <div className="h-4 bg-muted/65 rounded w-24 border-b border-border/50 pb-2" />
            <div className="space-y-2">
              <div className="flex justify-between"><div className="h-3 bg-muted/40 rounded w-16" /><div className="h-3 bg-muted/50 rounded w-10" /></div>
              <div className="flex justify-between"><div className="h-3 bg-muted/40 rounded w-20" /><div className="h-3 bg-muted/50 rounded w-10" /></div>
              <div className="flex justify-between border-t border-border/50 pt-2"><div className="h-4 bg-muted/65 rounded w-12" /><div className="h-4 bg-muted/75 rounded w-12" /></div>
            </div>
            <div className="h-10 bg-muted/60 rounded-xl w-full" />
          </div>
        </div>
      </div>
    </div>
  )
}

// 9. Checkout Page Skeleton
export function CheckoutSkeleton() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-5xl animate-pulse">
      <div className="h-7 bg-muted/65 rounded w-36 mb-6" />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8 items-start">
        {/* Left two columns: details */}
        <div className="md:col-span-2 space-y-6">
          {/* Shipping Address box */}
          <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-3">
            <div className="h-4 bg-muted/65 rounded w-32" />
            <div className="h-16 bg-muted/20 border border-border/40 rounded-xl w-full" />
          </div>

          {/* Payment method selection box */}
          <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-3">
            <div className="h-4 bg-muted/65 rounded w-28" />
            <div className="space-y-2">
              <div className="h-11 bg-muted/30 border border-border/40 rounded-xl w-full" />
              <div className="h-11 bg-muted/30 border border-border/40 rounded-xl w-full" />
            </div>
          </div>
        </div>

        {/* Right column: Order overview */}
        <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-4">
          <div className="h-4 bg-muted/65 rounded w-24" />
          <div className="space-y-2">
            <div className="h-3 bg-muted/40 rounded w-full" />
            <div className="h-3 bg-muted/40 rounded w-5/6" />
          </div>
          <div className="h-10 bg-muted/65 rounded-xl w-full" />
        </div>
      </div>
    </div>
  )
}

// 10. User Account / Profile Page Skeleton
export function AccountSkeleton() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl space-y-8 animate-pulse">
      {/* Profile summary card */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm flex items-center gap-4">
        <div className="w-16 h-16 rounded-full bg-muted/45 shrink-0" />
        <div className="space-y-2 flex-1">
          <div className="h-5 bg-muted/65 rounded w-40" />
          <div className="h-3.5 bg-muted/40 rounded w-56" />
        </div>
      </div>

      {/* Orders log history */}
      <div className="space-y-4">
        <div className="h-5 bg-muted/65 rounded w-32" />
        <div className="space-y-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <div key={i} className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-3">
              <div className="flex justify-between border-b border-border/40 pb-2.5">
                <div className="space-y-1"><div className="h-3.5 bg-muted/65 rounded w-24" /><div className="h-3 bg-muted/40 rounded w-16" /></div>
                <div className="h-5 bg-muted/50 rounded w-16" />
              </div>
              <div className="space-y-1">
                <div className="h-3 bg-muted/40 rounded w-2/3" />
                <div className="h-3 bg-muted/40 rounded w-1/3" />
              </div>
              <div className="flex justify-between items-center pt-2">
                <div className="h-4 bg-muted/70 rounded w-16" />
                <div className="h-8 bg-muted/50 rounded-lg w-20" />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}

// 11. Order Details & Live Tracking Status Skeleton
export function OrderDetailsSkeleton() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-3xl space-y-6 animate-pulse">
      {/* Header status */}
      <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-3">
        <div className="flex justify-between items-start"><div className="space-y-1.5"><div className="h-5 bg-muted/65 rounded w-36" /><div className="h-3 bg-muted/40 rounded w-28" /></div><div className="h-8 bg-muted/55 rounded-lg w-20" /></div>
      </div>

      {/* Stepper Status tracker */}
      <div className="bg-card border border-border p-6 rounded-2xl shadow-sm space-y-6">
        <div className="h-4.5 bg-muted/65 rounded w-24 border-b border-border/50 pb-2" />
        <div className="relative pl-8 space-y-8 before:absolute before:left-3.5 before:top-2 before:bottom-2 before:w-0.5 before:bg-muted/40">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="relative flex gap-4 items-start">
              {/* Stepper dot */}
              <div className="absolute -left-7.5 h-6.5 w-6.5 rounded-full bg-muted/60 border-4 border-card flex items-center justify-center shrink-0" />
              {/* Labels */}
              <div className="space-y-1"><div className="h-3.5 bg-muted/65 rounded w-32" /><div className="h-3 bg-muted/40 rounded w-44" /></div>
            </div>
          ))}
        </div>
      </div>

      {/* Items review box */}
      <div className="bg-card border border-border p-5 rounded-2xl shadow-sm space-y-3">
        <div className="h-4 bg-muted/65 rounded w-28 border-b border-border/50 pb-2" />
        <div className="space-y-2">
          <div className="h-3.5 bg-muted/40 rounded w-full" />
          <div className="h-3.5 bg-muted/40 rounded w-5/6" />
        </div>
      </div>
    </div>
  )
}

// 12. Admin Console Page Skeleton
export function AdminSkeleton() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 bg-background animate-pulse">
      {/* Title Header */}
      <div className="flex justify-between items-center border-b border-border/60 pb-4">
        <div className="space-y-1.5"><div className="h-6 bg-muted/65 rounded w-40" /><div className="h-3.5 bg-muted/40 rounded w-80" /></div>
      </div>

      {/* Grid of Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="bg-card border border-border p-5 rounded-2xl shadow-sm flex items-center gap-4">
            <div className="h-11 w-11 rounded-xl bg-muted/30 shrink-0" />
            <div className="space-y-1.5 flex-1"><div className="h-3 bg-muted/45 rounded w-16" /><div className="h-4.5 bg-muted/65 rounded w-12" /></div>
          </div>
        ))}
      </div>

      {/* Console Panels */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-card border border-border p-6 rounded-2xl shadow-sm h-64" />
        <div className="bg-card border border-border p-6 rounded-2xl shadow-sm h-64" />
      </div>
    </div>
  )
}

// 13. Picker / Delivery / Kitchen Operational Consoles Skeleton
export function OperationalSkeleton({ title = 'Console' }: { title?: string }) {
  return (
    <div className="container mx-auto px-4 py-6 max-w-6xl space-y-6 animate-pulse">
      {/* Header */}
      <div className="flex justify-between items-center border-b border-border/50 pb-4">
        <div className="space-y-1.5"><div className="h-6 bg-muted/65 rounded w-32" /><div className="h-3.5 bg-muted/40 rounded w-48" /></div>
        <div className="h-8 bg-muted/50 rounded-lg w-20" />
      </div>

      {/* Grid of Tasks */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {Array.from({ length: 6 }).map((_, i) => (
          <div key={i} className="bg-card border border-border p-4 rounded-xl shadow-sm space-y-3">
            <div className="flex justify-between items-center border-b border-border/40 pb-2"><div className="h-4 bg-muted/65 rounded w-16" /><div className="h-4 bg-muted/40 rounded w-20" /></div>
            <div className="space-y-2"><div className="h-3 bg-muted/40 rounded w-full" /><div className="h-3 bg-muted/40 rounded w-4/5" /></div>
            <div className="h-8 bg-muted/55 rounded-lg w-full pt-1" />
          </div>
        ))}
      </div>
    </div>
  )
}
