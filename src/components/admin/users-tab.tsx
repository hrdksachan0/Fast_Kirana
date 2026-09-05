'use client'

import { useState } from 'react'
import { Search, Download, Loader2, Check, X } from 'lucide-react'
import { User } from '@prisma/client'
import { formatDate } from '@/lib/date-helpers'
import { formatDisplayEmail } from '@/lib/utils'

interface UserWithCount extends User {
  _count?: { orders: number }
  assignedStore?: { id: string; name: string } | null
}

interface UsersTabProps {
  users: UserWithCount[]
  userPage: number
  userTotal: number
  userSearch: string
  userRoleFilter: string
  userStatusFilter: string
  isExportingUsers: boolean
  editingPhoneUserId: string | null
  phoneInput: string
  savingPhoneId: string | null
  settingPasswordUserId: string | null
  passwordInput: string
  savingPasswordId: string | null
  isUpdatingBlockStatus: boolean
  setUserPage: (p: number) => void
  setUserSearch: (v: string) => void
  setUserRoleFilter: (v: string) => void
  setUserStatusFilter: (v: string) => void
  setEditingPhoneUserId: (id: string | null) => void
  setPhoneInput: (v: string) => void
  setSettingPasswordUserId: (id: string | null) => void
  setPasswordInput: (v: string) => void
  handleExportCustomersCsv: () => Promise<void>
  handleUserPhoneSave: (userId: string) => Promise<void>
  handleUserRoleChange: (userId: string, newRole: string) => Promise<void>
  handleUserStoreChange?: (userId: string, storeId: string) => Promise<void>
  handleSetPassword: (userId: string) => Promise<void>
  handleToggleBlock: (user: UserWithCount, shouldBlock: boolean, reason?: string) => Promise<void>
  onRequestBlock: (user: UserWithCount) => void
  renderPagination: (page: number, total: number, perPage: number, onChange: (p: number) => void) => React.ReactNode
  stores?: Array<{ id: string; name: string }>
}

export function UsersTab({
  users,
  userPage,
  userTotal,
  userSearch,
  userRoleFilter,
  userStatusFilter,
  isExportingUsers,
  editingPhoneUserId,
  phoneInput,
  savingPhoneId,
  settingPasswordUserId,
  passwordInput,
  savingPasswordId,
  isUpdatingBlockStatus,
  setUserPage,
  setUserSearch,
  setUserRoleFilter,
  setUserStatusFilter,
  setEditingPhoneUserId,
  setPhoneInput,
  setSettingPasswordUserId,
  setPasswordInput,
  handleExportCustomersCsv,
  handleUserPhoneSave,
  handleUserRoleChange,
  handleUserStoreChange,
  handleSetPassword,
  handleToggleBlock,
  onRequestBlock,
  renderPagination,
  stores = []
}: UsersTabProps) {
  return (
    <div className="bg-card border border-border rounded-2xl p-6 shadow-sm overflow-hidden animate-fade-in">
      {/* Header with export and filters */}
      <div className="flex flex-col md:flex-row gap-4 items-center justify-between mb-5 border-b border-border/40 pb-4">
        <div className="flex items-center justify-between w-full md:w-auto">
          <div>
            <h3 className="font-extrabold text-text-primary text-base">Customer Accounts</h3>
            <p className="text-[10px] text-text-secondary mt-0.5">Access user profiles and check transaction frequencies.</p>
          </div>
          <button
            onClick={handleExportCustomersCsv}
            disabled={isExportingUsers}
            className="ml-4 flex items-center gap-1.5 px-3 py-1.5 bg-emerald-600 hover:bg-emerald-500 text-white text-[10px] font-black rounded-xl transition-all cursor-pointer shadow-xs active:scale-95 disabled:opacity-50 shrink-0"
          >
            <Download className="h-3.5 w-3.5" />
            {isExportingUsers ? 'Exporting...' : '📥 Export Customers'}
          </button>
        </div>

        {/* Search and Filters */}
        <div className="flex gap-2 w-full md:w-auto flex-1 justify-end max-w-lg">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-2.5 h-3.5 w-3.5 text-text-muted" />
            <input
              type="text"
              placeholder="Search customers by name, email, phone..."
              value={userSearch}
              onChange={(e) => setUserSearch(e.target.value)}
              className="pl-9 pr-4 py-2 w-full text-[10px] rounded-xl border border-border bg-muted/20 focus:outline-none focus:border-primary font-semibold"
            />
          </div>
          <select
            value={userRoleFilter}
            onChange={(e) => setUserRoleFilter(e.target.value)}
            className="px-3 py-1.5 text-[10px] rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none cursor-pointer"
          >
            <option value="ALL">All Roles</option>
            <option value="USER">Customers</option>
            <option value="PICKER">Pickers</option>
            <option value="CHEF">Chefs</option>
            <option value="DELIVERY">Riders</option>
            <option value="ADMIN">Admins</option>
          </select>
          <select
            value={userStatusFilter}
            onChange={(e) => setUserStatusFilter(e.target.value)}
            className="px-3 py-1.5 text-[10px] rounded-xl border border-border bg-card font-bold text-text-secondary focus:outline-none cursor-pointer"
          >
            <option value="ALL">All Statuses</option>
            <option value="ACTIVE">🟢 Active Only</option>
            <option value="BLOCKED">🔴 Blocked Only</option>
          </select>
        </div>
      </div>

      {/* Users Table */}
      <div className="overflow-x-auto">
        <table className="w-full text-left border-collapse text-xs">
          <thead>
            <tr className="border-b border-border text-text-secondary uppercase tracking-wider font-bold">
              <th className="py-3 px-4">Name</th>
              <th className="py-3 px-4">Email</th>
              <th className="py-3 px-4">Phone</th>
              <th className="py-3 px-4 text-center">Role</th>
              <th className="py-3 px-4 text-center">Store Hub</th>
              <th className="py-3 px-4 text-center">Account Status</th>
              <th className="py-3 px-4 text-center">Password</th>
              <th className="py-3 px-4 text-center">Orders Placed</th>
              <th className="py-3 px-4 text-center">Joined Date</th>
              <th className="py-3 px-4 text-center">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border/40 font-semibold text-text-primary">
            {users.map((u) => (
              <tr key={u.id} className="hover:bg-muted/30">
                {/* Name */}
                <td className="py-3 px-4">
                  <div className="flex items-center gap-2">
                    <div className="h-7 w-7 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-[10px]">
                      {u.name?.charAt(0) || 'U'}
                    </div>
                    <span className="font-bold">{u.name || 'Anonymous User'}</span>
                  </div>
                </td>

                {/* Email */}
                <td className="py-3 px-4 font-medium text-text-secondary">{u.email}</td>

                {/* Phone */}
                <td className="py-3 px-4 font-mono">
                  {editingPhoneUserId === u.id ? (
                    <div className="flex items-center gap-1.5">
                      <input
                        type="text"
                        placeholder="+91..."
                        value={phoneInput}
                        onChange={(e) => setPhoneInput(e.target.value)}
                        className="w-28 px-2 py-1 text-[11px] border border-border rounded-lg bg-muted/30 focus:outline-none focus:border-primary font-medium"
                      />
                      <button
                        onClick={() => handleUserPhoneSave(u.id)}
                        disabled={savingPhoneId === u.id}
                        className="px-2 py-1 text-[10px] bg-emerald-600 text-white rounded-md font-bold hover:bg-emerald-700 disabled:opacity-50 cursor-pointer"
                      >
                        {savingPhoneId === u.id ? '...' : 'Save'}
                      </button>
                      <button
                        onClick={() => {
                          setEditingPhoneUserId(null)
                          setPhoneInput('')
                        }}
                        className="px-1.5 py-1 text-[10px] text-text-muted hover:text-text-primary cursor-pointer"
                      >
                        ✕
                      </button>
                    </div>
                  ) : (
                    <div className="flex items-center gap-1.5">
                      <span className="text-text-muted">{u.phone || 'N/A'}</span>
                      <button
                        onClick={() => {
                          setEditingPhoneUserId(u.id)
                          setPhoneInput(u.phone || '')
                        }}
                        className="text-[10px] text-primary hover:underline font-bold opacity-80 hover:opacity-100 cursor-pointer"
                        title="Edit Phone Number"
                      >
                        ✏️ Edit
                      </button>
                    </div>
                  )}
                </td>

                {/* Role */}
                <td className="py-3 px-4 text-center">
                  <select
                    value={u.role}
                    onChange={(e) => handleUserRoleChange(u.id, e.target.value)}
                    disabled={u.role === 'ADMIN'}
                    className="bg-muted px-2 py-1 rounded-lg border text-[11px] font-bold text-text-primary focus:outline-none cursor-pointer disabled:opacity-50"
                  >
                    <option value="USER">Customer (USER)</option>
                    <option value="PICKER">Grocery Picker</option>
                    <option value="CHEF">Cafe Chef</option>
                    <option value="DELIVERY">Delivery Rider</option>
                    <option value="ADMIN">Admin</option>
                  </select>
                </td>

                {/* Store Hub */}
                <td className="py-3 px-4 text-center">
                  {u.role === 'DELIVERY' || u.role === 'PICKER' || u.role === 'ADMIN' ? (
                    <select
                      value={u.assignedStoreId || ''}
                      onChange={(e) => handleUserStoreChange && handleUserStoreChange(u.id, e.target.value)}
                      className="bg-muted px-2 py-1 rounded-lg border text-[11px] font-bold text-text-primary focus:outline-none cursor-pointer"
                    >
                      <option value="">No Hub Assigned</option>
                      {stores && stores.length > 0 ? (
                        stores.map((s) => (
                          <option key={s.id} value={s.id}>
                            🏢 {s.name} Hub
                          </option>
                        ))
                      ) : (
                        <option value="hub-209206">🏢 Ghatampur Central Hub</option>
                      )}
                    </select>
                  ) : (
                    <span className="text-text-muted text-[10px]">—</span>
                  )}
                </td>

                {/* Account Status */}
                <td className="py-3 px-4 text-center">
                  {u.isBlocked ? (
                    <div className="flex flex-col items-center">
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9px] font-black bg-rose-500/10 text-rose-600 border border-rose-500/20" title={u.blockReason ? `Reason: ${u.blockReason}` : undefined}>
                        🔴 Blocked
                      </span>
                      {u.blockReason && (
                        <span className="text-[8px] text-rose-500/80 max-w-[120px] truncate mt-0.5 font-medium" title={u.blockReason}>
                          {u.blockReason}
                        </span>
                      )}
                    </div>
                  ) : (
                    <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[9px] font-black bg-emerald-500/10 text-emerald-600 border border-emerald-500/20">
                      🟢 Active
                    </span>
                  )}
                </td>

                {/* Password */}
                <td className="py-3 px-4 text-center">
                  {settingPasswordUserId === u.id ? (
                    <div className="flex items-center gap-1.5 justify-center">
                      <input
                        type="password"
                        placeholder="Min 6 chars"
                        value={passwordInput}
                        onChange={(e) => setPasswordInput(e.target.value)}
                        className="w-24 px-2 py-1 text-[11px] border border-border rounded-lg bg-muted/30 focus:outline-none focus:border-primary font-medium"
                        autoFocus
                      />
                      <button
                        onClick={() => handleSetPassword(u.id)}
                        disabled={savingPasswordId === u.id}
                        className="p-1 bg-accent text-white rounded-md hover:bg-accent/90 transition-colors"
                      >
                        {savingPasswordId === u.id ? (
                          <Loader2 className="h-3 w-3 animate-spin" />
                        ) : (
                          <Check className="h-3 w-3" />
                        )}
                      </button>
                      <button
                        onClick={() => { setSettingPasswordUserId(null); setPasswordInput('') }}
                        className="p-1 bg-muted text-text-secondary rounded-md hover:bg-muted/80 transition-colors"
                      >
                        <X className="h-3 w-3" />
                      </button>
                    </div>
                  ) : (
                    <button
                      onClick={() => { setSettingPasswordUserId(u.id); setPasswordInput('') }}
                      className="px-2.5 py-1 text-[10px] font-bold bg-primary/10 text-primary border border-primary/20 rounded-lg hover:bg-primary/20 transition-colors cursor-pointer"
                    >
                      🔑 {u.passwordHash ? 'Change Password' : 'Set Password'}
                    </button>
                  )}
                </td>

                {/* Orders Count */}
                <td className="py-3 px-4 text-center">
                  <span className="font-bold bg-muted px-2 py-0.5 rounded border text-[10px]">
                    {u._count?.orders || 0} orders
                  </span>
                </td>

                {/* Joined Date */}
                <td className="py-3 px-4 text-center text-text-muted font-medium">
                  {formatDate(u.createdAt, 'd MMM yyyy')}
                </td>

                {/* Actions */}
                <td className="py-3 px-4 text-center">
                  {u.role === 'ADMIN' ? (
                    <span className="text-[10px] text-text-muted italic">Admin</span>
                  ) : u.isBlocked ? (
                    <button
                      onClick={() => handleToggleBlock(u, false)}
                      disabled={isUpdatingBlockStatus}
                      className="px-2.5 py-1 text-[10px] font-bold bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 border border-emerald-500/20 rounded-lg transition-colors cursor-pointer active:scale-95 disabled:opacity-50"
                    >
                      Unblock
                    </button>
                  ) : (
                    <button
                      onClick={() => onRequestBlock(u)}
                      disabled={isUpdatingBlockStatus}
                      className="px-2.5 py-1 text-[10px] font-bold bg-rose-500/10 hover:bg-rose-500/20 text-rose-600 border border-rose-500/20 rounded-lg transition-colors cursor-pointer active:scale-95 disabled:opacity-50"
                    >
                      Block
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {renderPagination(userPage, userTotal, 10, setUserPage)}
    </div>
  )
}
