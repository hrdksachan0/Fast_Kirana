'use client'

import { useState, useEffect, useCallback } from 'react'
import { toast } from 'sonner'
import { formatDate } from '@/lib/date-helpers'

interface UseAdminUsersProps {
  initialUsers?: any[]
  initialUserCount?: number
  selectedHubId: string
  activeTab?: string
}

export function useAdminUsers({
  initialUsers,
  initialUserCount,
  selectedHubId,
  activeTab,
}: UseAdminUsersProps) {
  const [users, setUsers] = useState<any[]>(Array.isArray(initialUsers) ? initialUsers : [])
  const [userPage, setUserPage] = useState(1)
  const [userTotal, setUserTotal] = useState(initialUserCount || (Array.isArray(initialUsers) ? initialUsers.length : 0))
  const [isLoadingUsers, setIsLoadingUsers] = useState(false)
  const [userSearch, setUserSearch] = useState('')
  const [userRoleFilter, setUserRoleFilter] = useState('ALL')
  const [userStatusFilter, setUserStatusFilter] = useState('ALL')

  const [updatingUserRoleId, setUpdatingUserRoleId] = useState<string | null>(null)
  const [settingPasswordUserId, setSettingPasswordUserId] = useState<string | null>(null)
  const [passwordInput, setPasswordInput] = useState('')
  const [savingPasswordId, setSavingPasswordId] = useState<string | null>(null)
  const [editingPhoneUserId, setEditingPhoneUserId] = useState<string | null>(null)
  const [phoneInput, setPhoneInput] = useState('')
  const [savingPhoneId, setSavingPhoneId] = useState<string | null>(null)

  const [blockingUser, setBlockingUser] = useState<any | null>(null)
  const [blockReasonInput, setBlockReasonInput] = useState('')
  const [isUpdatingBlockStatus, setIsUpdatingBlockStatus] = useState(false)
  const [isExportingUsers, setIsExportingUsers] = useState(false)

  useEffect(() => {
    setUserPage(1)
  }, [userSearch, userRoleFilter, userStatusFilter, selectedHubId])

  const fetchUsers = useCallback(async () => {
    setIsLoadingUsers(true)
    try {
      const storeQuery =
        selectedHubId && selectedHubId !== 'all'
          ? `&storeId=${encodeURIComponent(selectedHubId)}`
          : ''
      const res = await fetch(
        `/api/admin/users?page=${userPage}&limit=10&search=${encodeURIComponent(
          userSearch
        )}&role=${userRoleFilter}&status=${userStatusFilter}${storeQuery}&t=${Date.now()}`
      )
      if (res.ok) {
        const data = await res.json()
        const fetchedUsers = Array.isArray(data)
          ? data
          : Array.isArray(data?.users)
          ? data.users
          : []
        setUsers(fetchedUsers)
        setUserTotal(typeof data?.total === 'number' ? data.total : fetchedUsers.length)
      }
    } catch (err) {
      console.error('Failed to fetch users:', err)
    } finally {
      setIsLoadingUsers(false)
    }
  }, [userPage, userSearch, userRoleFilter, userStatusFilter, selectedHubId])

  useEffect(() => {
    if (activeTab === 'users') {
      fetchUsers()
    }
  }, [fetchUsers, activeTab])

  const handleToggleBlock = async (userToBlock: any, isBlocked: boolean, reason?: string) => {
    setIsUpdatingBlockStatus(true)
    try {
      const res = await fetch('/api/admin/users/block', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: userToBlock.id,
          isBlocked,
          blockReason: reason,
        }),
      })
      const data = await res.json()
      if (!res.ok) {
        throw new Error(data.error || 'Failed to update user block status')
      }
      toast.success(data.message)
      setBlockingUser(null)
      setBlockReasonInput('')
      setUsers((prev) =>
        prev.map((u) =>
          u.id === userToBlock.id
            ? {
                ...u,
                isBlocked,
                blockReason: isBlocked ? reason?.trim() || 'Blocked by administrator' : null,
                blockedAt: isBlocked ? new Date().toISOString() : null,
              }
            : u
        )
      )
    } catch (err: any) {
      toast.error(err.message || 'Error updating block status')
    } finally {
      setIsUpdatingBlockStatus(false)
    }
  }

  const handleExportCustomersCsv = async () => {
    setIsExportingUsers(true)
    try {
      const res = await fetch(`/api/admin/users?limit=10000&role=USER&t=${Date.now()}`)
      if (!res.ok) throw new Error('Failed to fetch customers')
      const data = await res.json()
      const customers = data.users || []

      if (customers.length === 0) {
        toast.error('No customers found to export.')
        return
      }

      const headers = [
        'Name',
        'Email',
        'Phone',
        'Role',
        'Status',
        'Block Reason',
        'Orders Count',
        'Joined Date',
      ]
      const rows = customers.map((c: any) => [
        `"${(c.name || '').replace(/"/g, '""')}"`,
        `"${(c.email || '').replace(/"/g, '""')}"`,
        `"${(c.phone || '').replace(/"/g, '""')}"`,
        `"${c.role || 'USER'}"`,
        `"${c.isBlocked ? 'BLOCKED' : 'ACTIVE'}"`,
        `"${(c.blockReason || '').replace(/"/g, '""')}"`,
        c._count?.orders ?? 0,
        formatDate(c.createdAt, 'dd/MM/yyyy'),
      ])

      const csvContent = [headers.join(','), ...rows.map((r: any) => r.join(','))].join('\n')

      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.setAttribute('href', url)
      link.setAttribute('download', `customers_export_${new Date().toISOString().split('T')[0]}.csv`)
      link.style.visibility = 'hidden'
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      toast.success('Customers data exported successfully!')
    } catch (err) {
      console.error(err)
      toast.error('Could not export customer records.')
    } finally {
      setIsExportingUsers(false)
    }
  }

  const handleUserRoleChange = async (userId: string, newRole: string) => {
    setUpdatingUserRoleId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, role: newRole }),
      })

      if (res.ok) {
        setUsers(users.map((u) => (u.id === userId ? { ...u, role: newRole } : u)))
        toast.success('User role updated successfully!')
      } else {
        toast.error('Failed to update user role')
      }
    } catch (err) {
      toast.error('Error updating user role')
    } finally {
      setUpdatingUserRoleId(null)
    }
  }

  const handleUserStoreChange = async (userId: string, newStoreId: string) => {
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, assignedStoreId: newStoreId }),
      })

      if (res.ok) {
        setUsers(
          users.map((u) => (u.id === userId ? { ...u, assignedStoreId: newStoreId || null } : u))
        )
        toast.success('Staff/Rider Store Hub updated successfully!')
      } else {
        toast.error('Failed to update store hub')
      }
    } catch (err) {
      toast.error('Error updating store hub')
    }
  }

  const handleSetPassword = async (userId: string) => {
    if (!passwordInput || passwordInput.length < 6) {
      toast.error('Password must be at least 6 characters')
      return
    }
    setSavingPasswordId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, password: passwordInput }),
      })
      if (res.ok) {
        toast.success('Password set successfully! Worker can now login.')
        setSettingPasswordUserId(null)
        setPasswordInput('')
      } else {
        const data = await res.json()
        toast.error(data.error || 'Failed to set password')
      }
    } catch (err) {
      toast.error('Error setting password')
    } finally {
      setSavingPasswordId(null)
    }
  }

  const handleUserPhoneSave = async (userId: string) => {
    if (!phoneInput.trim()) {
      toast.error('Phone number cannot be empty')
      return
    }

    setSavingPhoneId(userId)
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, phone: phoneInput.trim() }),
      })

      if (!res.ok) throw new Error('Failed to update phone number')

      setUsers(users.map((u) => (u.id === userId ? { ...u, phone: phoneInput.trim() } : u)))
      toast.success('Phone number updated successfully!')
      setEditingPhoneUserId(null)
      setPhoneInput('')
    } catch (err: any) {
      toast.error(err.message || 'Error updating phone number')
    } finally {
      setSavingPhoneId(null)
    }
  }

  return {
    users,
    setUsers,
    userPage,
    setUserPage,
    userTotal,
    setUserTotal,
    isLoadingUsers,
    userSearch,
    setUserSearch,
    userRoleFilter,
    setUserRoleFilter,
    userStatusFilter,
    setUserStatusFilter,
    updatingUserRoleId,
    settingPasswordUserId,
    setSettingPasswordUserId,
    passwordInput,
    setPasswordInput,
    savingPasswordId,
    editingPhoneUserId,
    setEditingPhoneUserId,
    phoneInput,
    setPhoneInput,
    savingPhoneId,
    blockingUser,
    setBlockingUser,
    blockReasonInput,
    setBlockReasonInput,
    isUpdatingBlockStatus,
    isExportingUsers,
    fetchUsers,
    handleToggleBlock,
    handleExportCustomersCsv,
    handleUserRoleChange,
    handleUserStoreChange,
    handleSetPassword,
    handleUserPhoneSave,
  }
}
