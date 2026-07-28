export default function RestaurantLoading() {
  return (
    <div className="min-h-screen bg-background pb-20 animate-fade-in">
      {/* 1. Header Cover & Restaurant Banner Skeleton */}
      <div className="relative w-full bg-muted/40 overflow-hidden border-b border-border/40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-10">
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
            
            {/* Left Info Skeleton */}
            <div className="flex items-center gap-4 w-full md:w-auto">
              <div className="h-16 w-16 sm:h-20 sm:w-20 rounded-2xl bg-muted animate-pulse shrink-0 border border-border/60 shadow-sm" />
              <div className="space-y-2 flex-1 min-w-0">
                <div className="h-6 sm:h-8 w-48 sm:w-64 bg-muted animate-pulse rounded-xl" />
                <div className="h-4 w-36 sm:w-48 bg-muted/80 animate-pulse rounded-lg" />
                <div className="flex items-center gap-2 pt-1">
                  <div className="h-5 w-16 bg-muted animate-pulse rounded-full" />
                  <div className="h-5 w-24 bg-muted animate-pulse rounded-full" />
                </div>
              </div>
            </div>

            {/* Right SLA Badge Skeleton */}
            <div className="hidden md:flex items-center gap-4 bg-card/80 p-3 rounded-2xl border border-border/60 shrink-0">
              <div className="h-10 w-24 bg-muted animate-pulse rounded-xl" />
              <div className="h-8 w-[1px] bg-border" />
              <div className="h-10 w-24 bg-muted animate-pulse rounded-xl" />
            </div>

          </div>
        </div>
      </div>

      {/* 2. Top Category Pills Strip Skeleton */}
      <div className="sticky top-14 z-20 bg-background/95 backdrop-blur-md border-b border-border/50 py-3 px-4">
        <div className="max-w-7xl mx-auto flex items-center gap-2 overflow-x-auto scrollbar-none">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="h-9 w-28 sm:w-36 bg-muted animate-pulse rounded-full shrink-0" />
          ))}
        </div>
      </div>

      {/* 3. Main Storefront Grid Skeleton */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-6">
        <div className="flex gap-8 items-start">
          
          {/* Left Category Sidebar (Desktop) */}
          <div className="hidden lg:flex flex-col gap-2 w-64 shrink-0 sticky top-32">
            {[...Array(7)].map((_, i) => (
              <div key={i} className="h-12 w-full bg-muted/60 animate-pulse rounded-2xl" />
            ))}
          </div>

          {/* Right Product Grid Section */}
          <div className="flex-1 space-y-8 w-full">
            
            {/* Section Header */}
            <div className="space-y-2">
              <div className="h-6 w-48 bg-muted animate-pulse rounded-xl" />
              <div className="h-4 w-72 bg-muted/60 animate-pulse rounded-lg" />
            </div>

            {/* 6 Food Card Skeletons Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
              {[...Array(6)].map((_, i) => (
                <div key={i} className="bg-card border border-border/60 rounded-3xl p-3.5 space-y-3 shadow-xs">
                  {/* Image Placeholder */}
                  <div className="w-full h-40 sm:h-44 bg-muted animate-pulse rounded-2xl relative overflow-hidden">
                    <div className="absolute top-2 right-2 h-6 w-12 bg-card/60 rounded-full" />
                  </div>
                  {/* Content Placeholder */}
                  <div className="space-y-2 pt-1">
                    <div className="h-5 w-3/4 bg-muted animate-pulse rounded-lg" />
                    <div className="h-3 w-1/2 bg-muted/70 animate-pulse rounded-md" />
                    <div className="flex items-center justify-between pt-2">
                      <div className="h-6 w-16 bg-muted animate-pulse rounded-lg" />
                      <div className="h-9 w-20 bg-primary/20 animate-pulse rounded-xl" />
                    </div>
                  </div>
                </div>
              ))}
            </div>

          </div>

        </div>
      </div>
    </div>
  )
}
