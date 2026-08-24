export default function AccountLoading() {
  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl space-y-6 animate-pulse select-none">
      {/* Profile Header Skeleton */}
      <div className="p-6 rounded-3xl bg-card border border-border/50 flex items-center gap-4 shadow-xs">
        <div className="h-16 w-16 rounded-2xl bg-muted shrink-0" />
        <div className="space-y-2 flex-1">
          <div className="h-5 w-40 bg-muted rounded-lg" />
          <div className="h-3.5 w-56 bg-muted/60 rounded-md" />
        </div>
      </div>

      {/* Tabs Skeleton */}
      <div className="flex gap-2 border-b border-border/40 pb-2">
        <div className="h-9 w-28 bg-muted rounded-xl" />
        <div className="h-9 w-28 bg-muted/60 rounded-xl" />
        <div className="h-9 w-28 bg-muted/60 rounded-xl" />
      </div>

      {/* Content Skeleton */}
      <div className="space-y-4 pt-2">
        {[1, 2, 3].map((i) => (
          <div key={i} className="p-5 rounded-2xl border border-border/50 bg-card space-y-3 shadow-xs">
            <div className="flex justify-between items-center">
              <div className="h-4 w-32 bg-muted rounded-md" />
              <div className="h-5 w-20 bg-muted rounded-full" />
            </div>
            <div className="h-3 w-48 bg-muted/60 rounded-md" />
            <div className="h-3 w-24 bg-muted/40 rounded-md" />
          </div>
        ))}
      </div>
    </div>
  )
}
