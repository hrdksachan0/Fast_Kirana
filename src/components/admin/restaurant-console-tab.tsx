'use client'

import { AdminRestaurantConsole } from '@/components/admin/admin-restaurant-console'

interface RestaurantConsoleTabProps {}

export function RestaurantConsoleTab({}: RestaurantConsoleTabProps) {
  return (
    <div className="animate-fade-in">
      <AdminRestaurantConsole />
    </div>
  )
}
