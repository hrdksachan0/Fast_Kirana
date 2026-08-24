export default function AdminLoading() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-8 animate-pulse select-none">
      {/* Header Skeleton */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center border-b border-border/60 pb-4 gap-4">
        <div className="space-y-2">
          <div className="h-7 w-48 bg-muted rounded-xl" />
          <div className="h-3.5 w-72 bg-muted/60 rounded-lg" />
        </div>
        <div className="h-9 w-36 bg-muted rounded-xl" />
      </div>

      {/* Stats Cards Skeleton */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="p-4 rounded-2xl bg-card border border-border/50 space-y-3 shadow-xs">
            <div className="flex items-center justify-between">
              <div className="h-3 w-24 bg-muted/70 rounded-md" />
              <div className="h-7 w-7 bg-muted rounded-full" />
            </div>
            <div className="h-6 w-32 bg-muted rounded-lg" />
          </div>
        ))}
      </div>

      {/* Tabs Skeleton */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 border-b border-border/40">
        {[1, 2, 3, 4, 5, 6, 7].map((i) => (
          <div key={i} className="h-8 w-24 bg-muted rounded-xl shrink-0" />
        ))}
      </div>

      {/* Content Area Skeleton */}
      <div className="rounded-2xl border border-border/50 bg-card p-6 space-y-4 shadow-xs">
        <div className="flex items-center justify-between">
          <div className="h-4 w-40 bg-muted rounded-md" />
          <div className="h-8 w-32 bg-muted rounded-xl" />
        </div>
        <div className="space-y-3 pt-4">
          {[1, 2, 3, 4, 5].map((i) => (
            <div key={i} className="h-12 w-full bg-muted/40 rounded-xl" />
          ))}
        </div>
      </div>
    </div>
  )
}
