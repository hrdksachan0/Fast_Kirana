'use client'

import { useState, useEffect } from 'react'
import { PlusCircle, Loader2, Ticket, Pencil, Trash, Trash2, Percent, IndianRupee, ToggleRight, ToggleLeft, X } from 'lucide-react'
import { formatDate } from '@/lib/date-helpers'
import { toast } from 'sonner'

interface Category {
  id: string
  name: string
}

interface Coupon {
  id: string
  code: string
  discountType: string
  value: number
  minOrder: number | string
  maxDiscount: number | string | null
  maxUses: number | string | null
  expiresAt: string | null
  isActive: boolean
  categoryId: string | null
  oncePerCustomer: boolean
  usedCount: number
}

interface CouponEditForm {
  code: string
  discountType: string
  value: string
  minOrder: string
  maxDiscount: string
  maxUses: string
  expiresAt: string
  isActive: boolean
  categoryId: string
  oncePerCustomer: boolean
}

interface CouponsTabProps {
  coupons: Coupon[]
  categories: Category[]
  showAddCoupon: boolean
  isCreatingCoupon: boolean
  isLoadingCoupons: boolean
  savingCouponId: string | null
  deletingCouponId: string | null
  newCoupon: CouponEditForm
  editingCoupon: Coupon | null
  couponEditForm: CouponEditForm
  setShowAddCoupon: (v: boolean) => void
  setNewCoupon: (v: CouponEditForm) => void
  setEditingCoupon: (c: Coupon | null) => void
  setCouponEditForm: (v: CouponEditForm) => void
  handleCreateCoupon: (e: React.FormEvent) => Promise<void>
  saveCouponChanges: (e: React.FormEvent) => Promise<void>
  handleToggleCoupon: (couponId: string, currentActive: boolean) => Promise<void>
  handleDeleteCoupon: (couponId: string) => Promise<void>
  startEditingCoupon: (c: Coupon) => void
}

const emptyNewCoupon: CouponEditForm = {
  code: '',
  discountType: 'PERCENT',
  value: '',
  minOrder: '',
  maxDiscount: '',
  maxUses: '',
  expiresAt: '',
  isActive: true,
  categoryId: '',
  oncePerCustomer: false,
}

export function CouponsTab({
  coupons,
  categories,
  showAddCoupon,
  isCreatingCoupon,
  isLoadingCoupons,
  savingCouponId,
  deletingCouponId,
  newCoupon,
  editingCoupon,
  couponEditForm,
  setShowAddCoupon,
  setNewCoupon,
  setEditingCoupon,
  setCouponEditForm,
  handleCreateCoupon,
  saveCouponChanges,
  handleToggleCoupon,
  handleDeleteCoupon,
  startEditingCoupon,
}: CouponsTabProps) {
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between">
        <div>
          <h3 className="font-extrabold text-text-primary text-base">Offers & Coupons</h3>
          <p className="text-[10px] text-text-secondary mt-0.5">
            Create, edit and manage promotional discount codes for customers
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 bg-purple-500/10 border border-purple-500/20 px-3 py-1.5 rounded-xl">
            <Ticket className="h-4 w-4 text-purple-500" />
            <span className="text-[11px] font-bold text-purple-600 dark:text-purple-400">
              {coupons.filter((c) => c.isActive).length} active / {coupons.length} total
            </span>
          </div>
          <button
            onClick={() => setShowAddCoupon(!showAddCoupon)}
            className="flex items-center gap-1.5 px-4 py-2 bg-primary text-primary-foreground text-xs font-bold rounded-xl hover:bg-primary/95 transition-all"
          >
            <PlusCircle className="h-4 w-4" />
            New Coupon
          </button>
        </div>
      </div>

      {/* Add Coupon Form */}
      {showAddCoupon && (
        <form
          onSubmit={handleCreateCoupon}
          className="bg-card p-6 border border-border rounded-2xl shadow-sm space-y-4 animate-slide-up"
        >
          <div className="border-b border-border/60 pb-2">
            <h4 className="font-extrabold text-text-primary text-sm">Create New Coupon</h4>
            <p className="text-[10px] text-text-secondary mt-0.5">Configure discount code, type, and usage limits</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Coupon Code *</label>
              <input
                type="text"
                required
                placeholder="e.g. SAVE20, WELCOME50"
                value={newCoupon.code}
                onChange={(e) => setNewCoupon({ ...newCoupon, code: e.target.value.toUpperCase() })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold uppercase tracking-wider"
              />
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Discount Type *</label>
              <select
                value={newCoupon.discountType}
                onChange={(e) => setNewCoupon({ ...newCoupon, discountType: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              >
                <option value="PERCENT">Percentage (%)</option>
                <option value="FLAT">Flat Amount (₹)</option>
              </select>
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">
                Discount Value * {newCoupon.discountType === 'PERCENT' ? '(%)' : '(₹)'}
              </label>
              <input
                type="number"
                step="0.01"
                required
                placeholder={newCoupon.discountType === 'PERCENT' ? 'e.g. 20' : 'e.g. 50'}
                value={newCoupon.value}
                onChange={(e) => setNewCoupon({ ...newCoupon, value: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Order Value (₹)</label>
              <input
                type="number"
                step="0.01"
                placeholder="e.g. 200"
                value={newCoupon.minOrder}
                onChange={(e) => setNewCoupon({ ...newCoupon, minOrder: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Discount Cap (₹)</label>
              <input
                type="number"
                step="0.01"
                placeholder="e.g. 100"
                value={newCoupon.maxDiscount}
                onChange={(e) => setNewCoupon({ ...newCoupon, maxDiscount: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Total Uses</label>
              <input
                type="number"
                placeholder="e.g. 100 (leave blank for unlimited)"
                value={newCoupon.maxUses}
                onChange={(e) => setNewCoupon({ ...newCoupon, maxUses: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
              <input
                type="date"
                value={newCoupon.expiresAt}
                onChange={(e) => setNewCoupon({ ...newCoupon, expiresAt: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              />
            </div>

            <div>
              <label className="text-[10px] font-bold text-text-secondary block mb-1">Restricted Category (Optional)</label>
              <select
                value={newCoupon.categoryId}
                onChange={(e) => setNewCoupon({ ...newCoupon, categoryId: e.target.value })}
                className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
              >
                <option value="">All Categories (No restriction)</option>
                {categories.map((cat) => (
                  <option key={cat.id} value={cat.id}>{cat.name}</option>
                ))}
              </select>
            </div>

            <div className="flex flex-col gap-3 pt-4">
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="couponActive"
                  checked={newCoupon.isActive}
                  onChange={(e) => setNewCoupon({ ...newCoupon, isActive: e.target.checked })}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <label htmlFor="couponActive" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  Activate Immediately
                </label>
              </div>

              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="oncePerCustomer"
                  checked={newCoupon.oncePerCustomer}
                  onChange={(e) => setNewCoupon({ ...newCoupon, oncePerCustomer: e.target.checked })}
                  className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                />
                <label htmlFor="oncePerCustomer" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                  Limit to once per customer
                </label>
              </div>
            </div>
          </div>

          <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
            <button
              type="button"
              onClick={() => {
                setShowAddCoupon(false)
                setNewCoupon(emptyNewCoupon)
              }}
              className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isCreatingCoupon}
              className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm"
            >
              {isCreatingCoupon ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Creating...
                </>
              ) : (
                'Create Coupon'
              )}
            </button>
          </div>
        </form>
      )}

      {/* Coupons List */}
      <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden">
        <h3 className="font-extrabold text-text-primary text-base mb-4">All Coupons</h3>
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse text-xs">
            <thead>
              <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
                <th className="py-3 px-4">Code</th>
                <th className="py-3 px-4">Type</th>
                <th className="py-3 px-4">Value</th>
                <th className="py-3 px-4">Min Order</th>
                <th className="py-3 px-4">Max Discount</th>
                <th className="py-3 px-4 text-center">Usage</th>
                <th className="py-3 px-4 text-center">Status</th>
                <th className="py-3 px-4">Expires</th>
                <th className="py-3 px-4 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border/40 font-semibold">
              {isLoadingCoupons ? (
                <tr>
                  <td colSpan={9} className="text-center py-10 text-text-secondary">
                    <Loader2 className="h-8 w-8 animate-spin mx-auto mb-2 text-primary" />
                    Loading coupons...
                  </td>
                </tr>
              ) : coupons.length === 0 ? (
                <tr>
                  <td colSpan={9} className="text-center py-10 text-text-secondary">
                    <Ticket className="h-8 w-8 mx-auto mb-2 text-text-muted" />
                    No coupons created yet.
                  </td>
                </tr>
              ) : (
                coupons.map((c) => {
                  const isExpired = c.expiresAt && new Date(c.expiresAt) < new Date()

                  return (
                    <tr key={c.id} className={`hover:bg-muted/30 ${isExpired ? 'opacity-60' : ''}`}>
                      {/* Code */}
                      <td className="py-3 px-4">
                        <span className="font-mono font-black text-[11px] bg-purple-500/10 text-purple-600 dark:text-purple-400 px-2 py-0.5 rounded-lg border border-purple-500/20">
                          {c.code}
                        </span>
                      </td>

                      {/* Type */}
                      <td className="py-3 px-4">
                        <span className="flex items-center gap-1 text-[11px]">
                          {c.discountType === 'PERCENT' ? (
                            <><Percent className="h-3 w-3 text-blue-500" /> Percent</>
                          ) : (
                            <><IndianRupee className="h-3 w-3 text-accent" /> Flat</>
                          )}
                        </span>
                      </td>

                      {/* Value */}
                      <td className="py-3 px-4">
                        <span className="font-extrabold text-accent">
                          {c.discountType === 'PERCENT' ? `${c.value}%` : `₹${c.value}`}
                        </span>
                      </td>

                      {/* Min Order */}
                      <td className="py-3 px-4">
                        <span className="text-text-secondary">₹{c.minOrder}</span>
                      </td>

                      {/* Max Discount */}
                      <td className="py-3 px-4">
                        <span className="text-text-secondary">
                          {c.maxDiscount ? `₹${c.maxDiscount}` : '—'}
                        </span>
                      </td>

                      {/* Usage */}
                      <td className="py-3 px-4 text-center">
                        <span className="bg-muted px-2 py-0.5 rounded border text-[10px] font-bold">
                          {c.usedCount}{c.maxUses ? ` / ${c.maxUses}` : ' / ∞'}
                        </span>
                      </td>

                      {/* Status */}
                      <td className="py-3 px-4 text-center">
                        <button
                          onClick={() => handleToggleCoupon(c.id, c.isActive)}
                          disabled={savingCouponId === c.id}
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9px] font-bold cursor-pointer transition-all ${
                            c.isActive
                              ? 'bg-accent/15 text-accent border border-accent/20 hover:bg-accent/25'
                              : 'bg-muted text-text-muted border border-border hover:bg-muted/80'
                          }`}
                        >
                          {savingCouponId === c.id ? (
                            <Loader2 className="h-3 w-3 animate-spin" />
                          ) : c.isActive ? (
                            <ToggleRight className="h-3 w-3" />
                          ) : (
                            <ToggleLeft className="h-3 w-3" />
                          )}
                          {c.isActive ? 'Active' : 'Disabled'}
                        </button>
                      </td>

                      {/* Expires */}
                      <td className="py-3 px-4">
                        <span className={`text-[10px] font-medium ${isExpired ? 'text-discount font-bold' : 'text-text-muted'}`}>
                          {c.expiresAt
                            ? formatDate(c.expiresAt, 'd MMM yyyy')
                            : 'Never'}
                          {isExpired && ' (Expired)'}
                        </span>
                      </td>

                      {/* Actions */}
                      <td className="py-3 px-4 text-right">
                        <div className="flex items-center justify-end gap-1.5">
                          <button
                            onClick={() => startEditingCoupon(c)}
                            className="p-1.5 border border-border hover:bg-muted text-text-secondary rounded-lg transition-colors"
                            title="Edit coupon"
                          >
                            <Pencil className="h-3.5 w-3.5" />
                          </button>
                          <button
                            onClick={() => handleDeleteCoupon(c.id)}
                            disabled={deletingCouponId === c.id}
                            className="p-1.5 border border-border text-discount hover:bg-discount/10 hover:border-discount/20 rounded-lg transition-colors"
                            title="Delete coupon"
                          >
                            {deletingCouponId === c.id ? (
                              <Loader2 className="h-3.5 w-3.5 animate-spin" />
                            ) : (
                              <Trash2 className="h-3.5 w-3.5" />
                            )}
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Edit Coupon Modal */}
      {editingCoupon && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm animate-fade-in p-4">
          <div className="bg-card border border-border rounded-2xl shadow-xl w-full max-w-lg p-6 animate-scale-up space-y-4">
            <div className="flex justify-between items-center border-b border-border/60 pb-3">
              <h4 className="font-extrabold text-text-primary text-base">Edit Coupon</h4>
              <button onClick={() => setEditingCoupon(null)} className="text-text-secondary hover:text-text-primary">
                <X className="h-5 w-5" />
              </button>
            </div>
            <form onSubmit={saveCouponChanges} className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Coupon Code *</label>
                  <input
                    type="text"
                    required
                    value={couponEditForm.code}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, code: e.target.value.toUpperCase() })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-bold uppercase tracking-wider"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Discount Type *</label>
                  <select
                    value={couponEditForm.discountType}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, discountType: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  >
                    <option value="PERCENT">Percentage (%)</option>
                    <option value="FLAT">Flat Amount (₹)</option>
                  </select>
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">
                    Discount Value * {couponEditForm.discountType === 'PERCENT' ? '(%)' : '(₹)'}
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    value={couponEditForm.value}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, value: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Min Order Value (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={couponEditForm.minOrder}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, minOrder: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Discount Cap (₹)</label>
                  <input
                    type="number"
                    step="0.01"
                    value={couponEditForm.maxDiscount}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, maxDiscount: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    placeholder="Unlimited"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Max Total Uses</label>
                  <input
                    type="number"
                    value={couponEditForm.maxUses}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, maxUses: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                    placeholder="Unlimited"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Expiry Date</label>
                  <input
                    type="date"
                    value={couponEditForm.expiresAt}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, expiresAt: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  />
                </div>
                <div>
                  <label className="text-[10px] font-bold text-text-secondary block mb-1">Restricted Category (Optional)</label>
                  <select
                    value={couponEditForm.categoryId}
                    onChange={(e) => setCouponEditForm({ ...couponEditForm, categoryId: e.target.value })}
                    className="w-full px-3 py-2 text-xs rounded-xl border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
                  >
                    <option value="">All Categories (No restriction)</option>
                    {categories.map((cat) => (
                      <option key={cat.id} value={cat.id}>{cat.name}</option>
                    ))}
                  </select>
                </div>
                <div className="flex flex-col gap-3 pt-4">
                  <div className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      id="editCouponActive"
                      checked={couponEditForm.isActive}
                      onChange={(e) => setCouponEditForm({ ...couponEditForm, isActive: e.target.checked })}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <label htmlFor="editCouponActive" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                      Coupon is Active
                    </label>
                  </div>
                  <div className="flex items-center gap-2">
                    <input
                      type="checkbox"
                      id="editOncePerCustomer"
                      checked={couponEditForm.oncePerCustomer}
                      onChange={(e) => setCouponEditForm({ ...couponEditForm, oncePerCustomer: e.target.checked })}
                      className="h-4 w-4 text-primary focus:ring-primary border-border rounded cursor-pointer"
                    />
                    <label htmlFor="editOncePerCustomer" className="text-xs font-bold text-text-primary cursor-pointer select-none">
                      Limit to once per customer
                    </label>
                  </div>
                </div>
              </div>
              <div className="flex justify-end gap-2 border-t border-border/40 pt-4">
                <button
                  type="button"
                  onClick={() => setEditingCoupon(null)}
                  className="px-4 py-2 border rounded-xl text-xs font-bold hover:bg-muted/50 transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingCouponId === editingCoupon.id}
                  className="flex items-center gap-1 px-5 py-2 bg-accent text-white text-xs font-bold rounded-xl hover:bg-accent/90 transition-all shadow-sm font-semibold disabled:opacity-50"
                >
                  {savingCouponId === editingCoupon.id ? (
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
      )}
    </div>
  )
}
