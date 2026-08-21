'use client'

import { useState, useEffect, useMemo } from 'react'
import { Star, RefreshCw, MessageSquare, ThumbsUp, Filter, User, Search } from 'lucide-react'
import { formatDate } from '@/lib/date-helpers'

interface ReviewItem {
  id: string
  rating: number
  comment: string | null
  createdAt: string
  user: {
    name: string | null
    image: string | null
  }
}

interface RestaurantReviewsTabProps {
  restaurantId?: string
}

export function RestaurantReviewsTab({ restaurantId }: RestaurantReviewsTabProps) {
  const [reviews, setReviews] = useState<ReviewItem[]>([])
  const [loading, setLoading] = useState(true)
  const [filterRating, setFilterRating] = useState<number | 'ALL'>('ALL')
  const [searchQuery, setSearchQuery] = useState('')

  const fetchReviews = async () => {
    setLoading(true)
    try {
      // If restaurantId is not provided, fetch from current user session assigned restaurant
      let targetId = restaurantId
      if (!targetId) {
        const resUser = await fetch('/api/auth/session')
        const sessionData = await resUser.json()
        targetId = sessionData?.user?.assignedRestaurantId || 'as-restaurant'
      }

      const res = await fetch(`/api/restaurants/${targetId}/reviews?t=${Date.now()}`)
      if (res.ok) {
        const data = await res.json()
        setReviews(data.reviews || [])
      }
    } catch (err) {
      console.error('Failed to load restaurant reviews:', err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    fetchReviews()
  }, [restaurantId])

  const stats = useMemo(() => {
    if (reviews.length === 0) return { avg: 4.0, total: 0, counts: { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 } }

    const sum = reviews.reduce((acc, r) => acc + r.rating, 0)
    const avg = Math.round((sum / reviews.length) * 10) / 10

    const counts = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 }
    reviews.forEach((r) => {
      const star = Math.min(5, Math.max(1, r.rating)) as keyof typeof counts
      counts[star] = (counts[star] || 0) + 1
    })

    return { avg, total: reviews.length, counts }
  }, [reviews])

  const filteredReviews = useMemo(() => {
    return reviews.filter((r) => {
      if (filterRating !== 'ALL' && r.rating !== filterRating) return false
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase()
        const commentMatch = (r.comment || '').toLowerCase().includes(q)
        const nameMatch = (r.user.name || '').toLowerCase().includes(q)
        if (!commentMatch && !nameMatch) return false
      }
      return true
    })
  }, [reviews, filterRating, searchQuery])

  return (
    <div className="space-y-6">
      {/* Overview Stats Bar */}
      <div className="bg-card border border-border/70 rounded-3xl p-5 shadow-xs">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-5">
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 rounded-2xl bg-amber-500/10 border border-amber-500/20 text-amber-500 flex flex-col items-center justify-center shrink-0">
              <span className="text-2xl font-black">{stats.avg}</span>
              <div className="flex text-amber-400 text-[10px]">★</div>
            </div>
            <div>
              <h2 className="text-base font-black text-text-primary">Customer Ratings & Feedback</h2>
              <p className="text-xs text-text-secondary mt-0.5">
                Total {stats.total} customer reviews received for your kitchen outlet.
              </p>
            </div>
          </div>

          <button
            onClick={fetchReviews}
            disabled={loading}
            className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-black bg-secondary hover:bg-secondary/80 border border-border text-text-primary rounded-xl transition-all cursor-pointer disabled:opacity-50 shrink-0"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh Reviews
          </button>
        </div>

        {/* Rating Breakdown Progress Bars */}
        <div className="grid grid-cols-2 sm:grid-cols-5 gap-2.5 mt-5 pt-4 border-t border-border/40">
          {[5, 4, 3, 2, 1].map((star) => {
            const count = stats.counts[star as keyof typeof stats.counts] || 0
            const pct = stats.total > 0 ? Math.round((count / stats.total) * 100) : 0
            return (
              <button
                key={star}
                onClick={() => setFilterRating(filterRating === star ? 'ALL' : star)}
                className={`p-2.5 rounded-2xl border text-left transition-all cursor-pointer ${
                  filterRating === star
                    ? 'bg-amber-500/10 border-amber-500/40 text-amber-600 dark:text-amber-400'
                    : 'bg-muted/30 border-border/40 text-text-secondary hover:border-border'
                }`}
              >
                <div className="flex items-center justify-between text-[10px] font-black mb-1">
                  <span>{star} Stars</span>
                  <span>{count}</span>
                </div>
                <div className="h-1.5 w-full bg-border/40 rounded-full overflow-hidden">
                  <div className="h-full bg-amber-400 rounded-full" style={{ width: `${pct}%` }} />
                </div>
              </button>
            )
          })}
        </div>
      </div>

      {/* Filter Controls */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-3">
        <div className="relative w-full sm:w-72">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-text-muted" />
          <input
            type="text"
            placeholder="Search in reviews..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full bg-card border border-border pl-9 pr-3 py-2 rounded-xl text-xs font-semibold focus:outline-none focus:border-primary"
          />
        </div>

        <div className="flex items-center gap-1.5 overflow-x-auto w-full sm:w-auto">
          <span className="text-[10px] font-black text-text-muted uppercase tracking-wider shrink-0 flex items-center gap-1">
            <Filter className="h-3 w-3" /> Filter:
          </span>
          <button
            onClick={() => setFilterRating('ALL')}
            className={`px-3 py-1.5 text-[10px] font-black rounded-lg transition-all cursor-pointer ${
              filterRating === 'ALL'
                ? 'bg-primary text-white shadow-xs'
                : 'bg-card border border-border text-text-secondary hover:text-text-primary'
            }`}
          >
            All ({reviews.length})
          </button>
          {[5, 4, 3, 2, 1].map((s) => (
            <button
              key={s}
              onClick={() => setFilterRating(s)}
              className={`px-2.5 py-1.5 text-[10px] font-black rounded-lg transition-all cursor-pointer ${
                filterRating === s
                  ? 'bg-amber-500 text-white shadow-xs'
                  : 'bg-card border border-border text-text-secondary hover:text-text-primary'
              }`}
            >
              {s} ★ ({stats.counts[s as keyof typeof stats.counts] || 0})
            </button>
          ))}
        </div>
      </div>

      {/* Reviews List */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <RefreshCw className="h-7 w-7 text-amber-500 animate-spin" />
          <p className="text-xs font-bold text-text-secondary">Loading customer reviews...</p>
        </div>
      ) : filteredReviews.length === 0 ? (
        <div className="text-center py-16 bg-muted/10 rounded-3xl border border-dashed border-border/60">
          <MessageSquare className="h-10 w-10 text-text-muted mx-auto mb-2 opacity-50" />
          <p className="text-xs font-black text-text-primary">No reviews found</p>
          <p className="text-[10px] text-text-muted mt-0.5">
            {filterRating !== 'ALL' ? `No ${filterRating}-star reviews match your filter.` : 'Customer feedback will appear here as soon as orders are delivered.'}
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {filteredReviews.map((rev) => (
            <div
              key={rev.id}
              className="bg-card border border-border/70 rounded-2xl p-4 space-y-2 shadow-2xs hover:border-border transition-colors"
            >
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2.5">
                  {rev.user?.image ? (
                    <img src={rev.user.image} alt="User" className="h-8 w-8 rounded-full object-cover border border-border/50" />
                  ) : (
                    <div className="h-8 w-8 rounded-full bg-secondary text-text-primary flex items-center justify-center text-xs font-black border border-border/50">
                      {(rev.user?.name || 'U').slice(0, 1).toUpperCase()}
                    </div>
                  )}
                  <div>
                    <h4 className="text-xs font-black text-text-primary">{rev.user?.name || 'Verified Customer'}</h4>
                    <p className="text-[9px] font-bold text-text-muted">{formatDate(rev.createdAt, 'dd MMM yyyy, hh:mm a')}</p>
                  </div>
                </div>

                <div className="flex items-center gap-1 bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20 px-2.5 py-1 rounded-full font-black text-xs">
                  <span>{rev.rating}</span>
                  <Star className="h-3 w-3 fill-amber-400 text-amber-400" />
                </div>
              </div>

              {rev.comment ? (
                <p className="text-xs font-medium text-text-secondary leading-relaxed bg-muted/20 p-2.5 rounded-xl border border-border/30">
                  &ldquo;{rev.comment}&rdquo;
                </p>
              ) : (
                <p className="text-[10px] italic text-text-muted">No written comment provided.</p>
              )}
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
