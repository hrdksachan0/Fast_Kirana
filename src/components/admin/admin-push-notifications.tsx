'use client'

import { useState, useEffect } from 'react'
import { toast } from 'sonner'
import { Send, Bell, History, CheckCircle2, XCircle, Loader2, Sparkles, Smartphone } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

interface PushNotificationHistory {
  id: string
  title: string
  body: string
  imageUrl: string | null
  linkUrl: string | null
  sentAt: string
  successCount: number
  failureCount: number
}

export function AdminPushNotifications() {
  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [imageUrl, setImageUrl] = useState('')
  const [linkUrl, setLinkUrl] = useState('')
  const [isSending, setIsSending] = useState(false)
  const [subscriberCount, setSubscriberCount] = useState<number | null>(null)
  const [history, setHistory] = useState<PushNotificationHistory[]>([])
  const [isLoadingHistory, setIsLoadingHistory] = useState(true)

  useEffect(() => {
    fetchNotificationData()
  }, [])

  const fetchNotificationData = async () => {
    try {
      const res = await fetch('/api/admin/push-notifications')
      if (res.ok) {
        const data = await res.json()
        setHistory(data.notifications || [])
        setSubscriberCount(data.subscriptionCount ?? 0)
      } else {
        console.error('Failed to fetch notifications history')
      }
    } catch (error) {
      console.error('Error fetching push notification data:', error)
    } finally {
      setIsLoadingHistory(false)
    }
  }

  const handleSendNotification = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!title.trim() || !body.trim()) {
      toast.error('Title and message are required')
      return
    }

    setIsSending(true)
    try {
      const res = await fetch('/api/admin/push-notifications', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          title: title.trim(),
          body: body.trim(),
          imageUrl: imageUrl.trim() || undefined,
          linkUrl: linkUrl.trim() || undefined,
        }),
      })

      if (res.ok) {
        const newLog = await res.json()
        setHistory([newLog, ...history])
        toast.success(`Notification broadcast completed! Sent successfully to ${newLog.successCount} devices.`)
        setTitle('')
        setBody('')
        setImageUrl('')
        setLinkUrl('')
        // Refresh counts to update the active subscriber stats
        fetchNotificationData()
      } else {
        const errData = await res.json()
        toast.error(errData.error || 'Failed to send notification')
      }
    } catch (error) {
      toast.error('Failed to send notification: Connection error')
    } finally {
      setIsSending(false)
    }
  }

  return (
    <div className="space-y-6">
      {/* Top Banner Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="relative overflow-hidden rounded-2xl border border-blue-500/10 bg-gradient-to-br from-blue-500/5 via-indigo-500/5 to-card p-5 shadow-sm">
          <div className="absolute right-0 top-0 -mr-4 -mt-4 h-16 w-16 rounded-full bg-blue-500/10 blur-lg" />
          <div className="flex items-center gap-3.5">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-blue-500/10 text-blue-600 dark:text-blue-400">
              <Smartphone className="h-5 w-5" />
            </div>
            <div>
              <p className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider">Active Devices</p>
              <h3 className="text-xl font-black text-text-primary mt-0.5">
                {subscriberCount !== null ? (
                  `${subscriberCount} Subscribed`
                ) : (
                  <Loader2 className="h-4 w-4 animate-spin text-blue-500" />
                )}
              </h3>
            </div>
          </div>
        </div>

        <div className="relative overflow-hidden rounded-2xl border border-accent/10 bg-gradient-to-br from-accent/5 via-purple-500/5 to-card p-5 shadow-sm">
          <div className="absolute right-0 top-0 -mr-4 -mt-4 h-16 w-16 rounded-full bg-accent/10 blur-lg" />
          <div className="flex items-center gap-3.5">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-accent/10 text-accent">
              <Sparkles className="h-5 w-5" />
            </div>
            <div>
              <p className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider">Total Broadcasts</p>
              <h3 className="text-xl font-black text-text-primary mt-0.5">{history.length} Campaigns</h3>
            </div>
          </div>
        </div>

        <div className="relative overflow-hidden rounded-2xl border border-emerald-500/10 bg-gradient-to-br from-emerald-500/5 via-teal-500/5 to-card p-5 shadow-sm">
          <div className="absolute right-0 top-0 -mr-4 -mt-4 h-16 w-16 rounded-full bg-emerald-500/10 blur-lg" />
          <div className="flex items-center gap-3.5">
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">
              <CheckCircle2 className="h-5 w-5" />
            </div>
            <div>
              <p className="text-[10px] font-extrabold text-text-secondary uppercase tracking-wider">Delivery Rate</p>
              <h3 className="text-xl font-black text-text-primary mt-0.5">
                {history.length > 0 ? (
                  (() => {
                    const totalSuccess = history.reduce((sum, h) => sum + h.successCount, 0)
                    const totalFailure = history.reduce((sum, h) => sum + h.failureCount, 0)
                    const totalSent = totalSuccess + totalFailure
                    return totalSent > 0 ? `${Math.round((totalSuccess / totalSent) * 100)}%` : '100%'
                  })()
                ) : (
                  '100%'
                )}
              </h3>
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
        {/* Composer Form */}
        <div className="lg:col-span-2 bg-card border border-border/60 rounded-2xl p-5 shadow-sm space-y-4">
          <div className="flex items-center gap-2 border-b border-border/40 pb-3">
            <Bell className="h-4.5 w-4.5 text-primary" />
            <h4 className="font-extrabold text-text-primary text-sm">Compose Notification</h4>
          </div>

          <form onSubmit={handleSendNotification} className="space-y-4">
            <div>
              <label htmlFor="push-title" className="block text-[10px] font-extrabold text-text-secondary uppercase tracking-wider mb-1.5">
                Campaign Title *
              </label>
              <input
                id="push-title"
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. Flash Deal Alert! ⚡"
                maxLength={80}
                required
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label htmlFor="push-body" className="block text-[10px] font-extrabold text-text-secondary uppercase tracking-wider mb-1.5">
                Notification Message *
              </label>
              <textarea
                id="push-body"
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="Write your push notification message here..."
                rows={3}
                maxLength={240}
                required
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold resize-none"
              />
            </div>

            <div>
              <label htmlFor="push-image" className="block text-[10px] font-extrabold text-text-secondary uppercase tracking-wider mb-1.5">
                Image URL (Optional)
              </label>
              <input
                id="push-image"
                type="url"
                value={imageUrl}
                onChange={(e) => setImageUrl(e.target.value)}
                placeholder="https://example.com/promo.jpg"
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label htmlFor="push-link" className="block text-[10px] font-extrabold text-text-secondary uppercase tracking-wider mb-1.5">
                Destination Link URL (Optional)
              </label>
              <input
                id="push-link"
                type="text"
                value={linkUrl}
                onChange={(e) => setLinkUrl(e.target.value)}
                placeholder="e.g. /product/mangoes or /category/snacks"
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <button
              type="submit"
              disabled={isSending || subscriberCount === 0}
              className="w-full flex items-center justify-center gap-2 px-4 py-2.5 bg-primary hover:bg-primary/90 text-white text-xs font-extrabold rounded-xl shadow-sm hover:shadow transition-all disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              {isSending ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Broadcasting Notification...
                </>
              ) : (
                <>
                  <Send className="h-3.5 w-3.5" />
                  Broadcast to All Devices
                </>
              )}
            </button>

            {subscriberCount === 0 && (
              <p className="text-[10px] text-amber-500 font-bold text-center">
                ⚠️ No subscribed users in the database to receive push notifications.
              </p>
            )}
          </form>
        </div>

        {/* Campaign History Log */}
        <div className="lg:col-span-3 bg-card border border-border/60 rounded-2xl p-5 shadow-sm space-y-4">
          <div className="flex items-center gap-2 border-b border-border/40 pb-3">
            <History className="h-4.5 w-4.5 text-text-secondary" />
            <h4 className="font-extrabold text-text-primary text-sm">Broadcast Campaigns History</h4>
          </div>

          {isLoadingHistory ? (
            <div className="flex flex-col items-center justify-center py-12 gap-3">
              <Loader2 className="h-8 w-8 animate-spin text-primary" />
              <p className="text-xs font-semibold text-text-secondary">Loading campaign history...</p>
            </div>
          ) : history.length === 0 ? (
            <div className="text-center py-12 border border-dashed border-border/50 rounded-2xl space-y-2">
              <Bell className="h-8 w-8 text-text-muted mx-auto opacity-40 animate-pulse" />
              <p className="text-xs font-extrabold text-text-secondary">No campaigns sent yet</p>
              <p className="text-[10px] text-text-muted">Compose your first campaign on the left to broadcast push alerts.</p>
            </div>
          ) : (
            <div className="max-h-[360px] overflow-y-auto rounded-xl border border-border/60">
              <table className="w-full text-xs">
                <thead className="bg-muted/40 sticky top-0 z-10">
                  <tr>
                    <th className="py-2.5 px-3 text-left font-extrabold text-text-secondary">Sent At</th>
                    <th className="py-2.5 px-3 text-left font-extrabold text-text-secondary">Notification</th>
                    <th className="py-2.5 px-3 text-right font-extrabold text-text-secondary">Delivered</th>
                    <th className="py-2.5 px-3 text-right font-extrabold text-text-secondary">Failed</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border/40">
                  {history.map((item) => (
                    <tr key={item.id} className="hover:bg-muted/20 transition-colors">
                      <td className="py-2.5 px-3 font-semibold text-text-muted whitespace-nowrap">
                        {new Date(item.sentAt).toLocaleString([], {
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit',
                        })}
                      </td>
                      <td className="py-2.5 px-3">
                        <div className="space-y-0.5">
                          <p className="font-bold text-text-primary">{item.title}</p>
                          <p className="text-[10px] text-text-secondary line-clamp-2 max-w-[200px]">{item.body}</p>
                          {item.linkUrl && (
                            <span className="inline-block text-[9px] bg-muted px-1.5 py-0.5 rounded font-bold text-primary max-w-[150px] truncate">
                              Link: {item.linkUrl}
                            </span>
                          )}
                        </div>
                      </td>
                      <td className="py-2.5 px-3 text-right font-extrabold text-emerald-600 dark:text-emerald-400">
                        {item.successCount}
                      </td>
                      <td className="py-2.5 px-3 text-right font-extrabold text-red-500">
                        {item.failureCount}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
