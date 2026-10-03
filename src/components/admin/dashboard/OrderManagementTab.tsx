'use client'

import React from 'react'
import { AdminLiveOrdersTab, AdminLiveOrdersTabProps } from '@/components/admin/dashboard/AdminLiveOrdersTab'

export interface OrderManagementTabProps extends AdminLiveOrdersTabProps {}

/**
 * OrderManagementTab
 * 
 * Modular subcomponent for the Admin Dashboard.
 * Encapsulates live order management, status updates, delay alerts,
 * WhatsApp recovery notifications, and customer order modals.
 */
export function OrderManagementTab(props: OrderManagementTabProps) {
  return (
    <div className="w-full space-y-4">
      <AdminLiveOrdersTab {...props} />
    </div>
  )
}

export default OrderManagementTab
