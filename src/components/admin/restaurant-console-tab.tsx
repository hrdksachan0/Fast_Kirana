'use client'

import { AdminRestaurantConsole } from '@/components/admin/admin-restaurant-console'

interface RestaurantConsoleTabProps {
  storeId?: string
}

export function RestaurantConsoleTab({ storeId }: RestaurantConsoleTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminRestaurantConsole storeId={storeId} />
    </div>
  )
}
