'use client'

import { useCallback } from 'react'
import { X, Loader2 } from 'lucide-react'

interface Review {
  id: string
  rating: number
  comment: string
}

interface ReviewEditModalProps {
  editingReview: Review | null
  reviewEditForm: {
    rating: number
    comment: string
  }
  savingReviewId: string | null
  saveReviewChanges: (e: React.FormEvent) => Promise<void>
  setEditingReview: (r: any) => void
  setReviewEditForm: (f: any) => void
}

export function ReviewEditModal({
  editingReview,
  reviewEditForm,
  savingReviewId,
  saveReviewChanges,
  setEditingReview,
  setReviewEditForm,
}: ReviewEditModalProps) {
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setEditingReview(null)
    }
  }, [setEditingReview])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="review-edit-title"
      onKeyDown={handleKeyDown}
    >
      <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-md p-6 animate-scale-up space-y-4">
        <div className="flex justify-between items-center border-b border-border/60 pb-3">
          <h4 id="review-edit-title" className="font-extrabold text-text-primary text-base">Edit Review</h4>
          <button onClick={() => setEditingReview(null)} className="text-text-secondary hover:text-text-primary" aria-label="Close review edit dialog">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={saveReviewChanges} className="space-y-4">
          <div className="space-y-3">
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Rating (1-5 Stars)</label>
              <select
                value={reviewEditForm.rating}
                onChange={(e) => setReviewEditForm({ ...reviewEditForm, rating: parseInt(e.target.value) || 5 })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold"
              >
                <option value="5">5 Stars ⭐⭐⭐⭐⭐</option>
                <option value="4">4 Stars ⭐⭐⭐⭐</option>
                <option value="3">3 Stars ⭐⭐⭐</option>
                <option value="2">2 Stars ⭐⭐</option>
                <option value="1">1 Star ⭐</option>
              </select>
            </div>
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Review Comment</label>
              <textarea
                rows={4}
                value={reviewEditForm.comment}
                onChange={(e) => setReviewEditForm({ ...reviewEditForm, comment: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>
          </div>
          <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
            <button
              type="button"
              onClick={() => setEditingReview(null)}
              className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={savingReviewId === editingReview?.id}
              className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold"
            >
              {savingReviewId === editingReview?.id ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Saving...
                </>
              ) : (
                'Save Changes'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
