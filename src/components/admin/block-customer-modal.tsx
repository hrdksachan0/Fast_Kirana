'use client'

import { X, Loader2 } from 'lucide-react'
import { useCallback } from 'react'
import { formatDisplayEmail } from '@/lib/utils'

interface BlockCustomerModalProps {
  blockingUser: { id: string; name: string; email: string } | null
  blockReasonInput: string
  isUpdatingBlockStatus: boolean
  setBlockingUser: (u: any) => void
  setBlockReasonInput: (r: string) => void
  handleToggleBlock: (user: any, block: boolean, reason: string) => void
}

export function BlockCustomerModal({
  blockingUser,
  blockReasonInput,
  isUpdatingBlockStatus,
  setBlockingUser,
  setBlockReasonInput,
  handleToggleBlock,
}: BlockCustomerModalProps) {
  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setBlockingUser(null)
    }
  }, [setBlockingUser])

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="block-customer-title"
      onKeyDown={handleKeyDown}
    >
      <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-md p-6 animate-scale-up space-y-4">
        <div className="flex justify-between items-center border-b border-border/60 pb-3">
          <div>
            <h4 className="font-extrabold text-text-primary text-base flex items-center gap-2">
              <span>🚫</span> Block Customer Account
            </h4>
            <p className="text-[10px] text-text-secondary mt-0.5 font-bold">
              Customer: <span className="font-extrabold text-text-primary">{blockingUser?.name || 'Anonymous User'}</span>
              {formatDisplayEmail(blockingUser?.email) ? ` (${formatDisplayEmail(blockingUser?.email)})` : ''}
            </p>
          </div>
          <button
            onClick={() => setBlockingUser(null)}
            className="text-text-secondary hover:text-text-primary p-1 rounded-lg hover:bg-muted cursor-pointer"
            aria-label="Close block customer dialog"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="space-y-3">
          <label className="text-[10px] font-bold text-text-secondary block">Select or Enter Reason for Blocking</label>
          <div className="flex flex-wrap gap-1.5">
            {[
              "Repeated Fake COD Orders",
              "Abusive Behavior",
              "Fraudulent Account",
              "Payment Default / Refusal"
            ].map((reason, idx) => (
              <button
                key={idx}
                type="button"
                onClick={() => setBlockReasonInput(reason)}
                className={`px-2.5 py-1 text-[10px] rounded-lg border transition-all font-bold cursor-pointer ${
                  blockReasonInput === reason
                    ? 'bg-rose-500/10 border-rose-500 text-rose-600 dark:text-rose-400'
                    : 'bg-muted/10 border-border hover:bg-muted/30 text-text-secondary'
                }`}
              >
                {reason}
              </button>
            ))}
          </div>

          <div className="space-y-1">
            <label className="text-[10px] font-bold text-text-secondary block">Reason Details (Optional)</label>
            <textarea
              value={blockReasonInput}
              onChange={(e) => setBlockReasonInput(e.target.value)}
              placeholder="Specify why this account is being blocked..."
              rows={3}
              className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-rose-500 font-bold leading-relaxed resize-none"
            />
          </div>
        </div>

        <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
          <button
            type="button"
            onClick={() => setBlockingUser(null)}
            className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all cursor-pointer"
          >
            Cancel
          </button>
          <button
            type="button"
            disabled={isUpdatingBlockStatus}
            onClick={() => handleToggleBlock(blockingUser, true, blockReasonInput)}
            className="flex items-center gap-1.5 px-5 py-2 bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold rounded-xl transition-all shadow-sm cursor-pointer disabled:opacity-50"
          >
            {isUpdatingBlockStatus ? <Loader2 className="h-4 w-4 animate-spin" /> : '🚫 Block Customer'}
          </button>
        </div>
      </div>
    </div>
  )
}
