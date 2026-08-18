'use client'

import React from 'react'
import { Star, Search, Loader2, MessageSquare, Trash } from 'lucide-react'
import { formatDate } from '@/lib/date-helpers'
import { formatDisplayEmail } from '@/lib/utils'

interface ReviewsTabProps {
  reviews: any[]
  reviewSearch: string
  setReviewSearch: (val: string) => void
  isLoadingReviews: boolean
  deletingReviewId: string | null
  startEditingReview: (review: any) => void
  handleDeleteReview: (id: string) => void
}

export function ReviewsTab({
  reviews,
  reviewSearch,
  setReviewSearch,
  isLoadingReviews,
  deletingReviewId,
  startEditingReview,
  handleDeleteReview,
}: ReviewsTabProps) {

  // Filtered reviews
  const filteredReviews = reviews.filter((r: any) => {
    if (!reviewSearch) return true
    const q = reviewSearch.toLowerCase()
    return (
      r.user.name?.toLowerCase().includes(q) ||
      r.user.email?.toLowerCase().includes(q) ||
      r.product.name?.toLowerCase().includes(q) ||
      r.comment?.toLowerCase().includes(q)
    )
  })

  // Star render helper
  const renderStars = (rating: number) => {
    return Array.from({ length: 5 }, (_, i) => (
      <Star
        key={i}
        className={`h-3.5 w-3.5 ${
          i < rating
            ? 'text-yellow-500 fill-yellow-500'
            : 'text-border'
        }`}
      />
    ))
  }

  // Calculate average rating
  const avgRating = reviews.length > 0 
    ? (reviews.reduce((sum: number, r: any) => sum + r.rating, 0) / reviews.length).toFixed(1)
    : '0.0'

  return (
    <div className="space-y-6 animate-fade-in">
      
      {/* Reviews header with stats */}
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between bg-card p-4 rounded-2xl border border-border shadow-sm">
        <div className="flex items-center gap-4">
          <div>
            <h3 className="font-extrabold text-text-primary text-base">Customer Reviews</h3>
            <p className="text-[10px] text-text-secondary mt-0.5">
              Monitor, moderate & manage all product feedback
            </p>
          </div>
          <div className="flex items-center gap-2 bg-yellow-500/10 border border-yellow-500/20 px-3 py-1.5 rounded-xl">
            <Star className="h-4 w-4 text-yellow-500 fill-yellow-500" />
            <span className="text-sm font-black text-yellow-600 dark:text-yellow-400">{avgRating}</span>
            <span className="text-[10px] font-bold text-text-secondary">avg ({reviews.length} reviews)</span>
          </div>
        </div>
        <div className="relative w-full md:w-72">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-text-muted" />
          <input
            type="text"
            placeholder="Search by customer, product, comment..."
            value={reviewSearch}
            onChange={(e) => setReviewSearch(e.target.value)}
            className="pl-9 pr-4 py-2 w-full text-xs rounded-xl border border-border bg-muted/30 focus:outline-none focus:border-primary font-semibold"
          />
        </div>
      </div>

      {/* Rating distribution bar */}
      <div className="bg-card border border-border rounded-2xl p-5 shadow-sm">
        <h4 className="text-xs font-extrabold text-text-primary mb-3">Rating Distribution</h4>
        <div className="space-y-2">
          {[5, 4, 3, 2, 1].map((star) => {
            const count = reviews.filter((r: any) => r.rating === star).length
            const pct = reviews.length > 0 ? (count / reviews.length) * 100 : 0
            return (
              <div key={star} className="flex items-center gap-3">
                <div className="flex items-center gap-0.5 w-16 justify-end">
                  <span className="text-[11px] font-bold text-text-primary">{star}</span>
                  <Star className="h-3 w-3 text-yellow-500 fill-yellow-500" />
                </div>
                <div className="flex-1 h-2.5 bg-muted/50 rounded-full overflow-hidden border border-border/40">
                  <div
                    className="h-full rounded-full transition-all duration-500"
                    style={{
                      width: `${pct}%`,
                      background: star >= 4
                        ? 'linear-gradient(90deg, #22c55e, #4ade80)'
                        : star === 3
                          ? 'linear-gradient(90deg, #eab308, #facc15)'
                          : 'linear-gradient(90deg, #ef4444, #f87171)',
                    }}
                  />
                </div>
                <span className="text-[10px] font-bold text-text-muted w-12 text-right">{count} ({pct.toFixed(0)}%)</span>
              </div>
            )
          })}
        </div>
      </div>

      {/* Reviews List */}
      <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                <th className="py-3 px-4">Customer</th>
                <th className="py-3 px-4">Product</th>
                <th className="py-3 px-4">Rating</th>
                <th className="py-3 px-4">Comment</th>
                <th className="py-3 px-4">Date</th>
                <th className="py-3 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/40 font-semibold">
              {isLoadingReviews ? (
                <tr>
                  <td colSpan={6} className="text-center py-10 text-text-secondary">
                    <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2 text-primary" />
                    Loading reviews...
                  </td>
                </tr>
              ) : filteredReviews.length === 0 ? (
                <tr>
                  <td colSpan={6} className="text-center py-10 text-text-secondary">
                    <MessageSquare className="h-8 w-8 mx-auto mb-2 text-text-muted" />
                    No reviews found.
                  </td>
                </tr>
              ) : (
                filteredReviews.map((r: any) => (
                  <tr key={r.id} className="hover:bg-muted/30">
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2">
                        <div className="h-7 w-7 rounded-full bg-yellow-500/10 flex items-center justify-center text-yellow-600 font-bold text-[10px]">
                          {r.user.name?.charAt(0) || 'U'}
                        </div>
                        <div>
                          <div className="font-bold text-text-primary text-[11px]">{r.user.name || 'Anonymous'}</div>
                          <div className="text-[9px] text-text-muted font-normal">{formatDisplayEmail(r.user.email)}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-2">
                        <span className="text-lg h-7 w-7 bg-muted/60 flex items-center justify-center rounded-lg border text-[11px]">
                          {r.product.imageUrl && r.product.imageUrl.length < 5 ? r.product.imageUrl : '📦'}
                        </span>
                        <span className="font-bold text-text-primary text-[11px] max-w-[140px] truncate">{r.product.name}</span>
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <div className="flex items-center gap-0.5">
                        {renderStars(r.rating)}
                      </div>
                    </td>
                    <td className="py-3 px-4">
                      <p className="text-text-secondary font-medium text-[11px] max-w-[250px] truncate">
                        {r.comment || <span className="italic text-text-muted">No comment</span>}
                      </p>
                    </td>
                    <td className="py-3 px-4 text-text-muted font-medium text-[10px]">
                      {formatDate(r.createdAt, 'd MMM yyyy')}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => startEditingReview(r)}
                          className="px-2.5 py-1 border border-border hover:bg-muted text-[10px] font-bold rounded-lg text-text-secondary transition-all"
                        >
                          Edit
                        </button>
                        <button
                          onClick={() => handleDeleteReview(r.id)}
                          disabled={deletingReviewId === r.id}
                          className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors inline-flex items-center justify-center"
                        >
                          {deletingReviewId === r.id ? (
                            <Loader2 className="h-3.5 w-3.5 animate-spin" />
                          ) : (
                            <Trash className="h-3.5 w-3.5" />
                          )}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

    </div>
  )
}
