'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { toast } from 'sonner'
import Link from 'next/link'
import { 
  Plus, 
  Search, 
  Edit, 
  Trash2, 
  Store,
  Star,
  ToggleLeft,
  ToggleRight,
  MapPin,
  Clock,
  Package,
  X
} from 'lucide-react'
import { RestaurantForm } from './restaurant-form'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Badge } from '@/components/ui/badge'
import { cn } from '@/lib/utils'

interface RestaurantManagerProps {
  initialRestaurants: any[]
}

export function RestaurantManager({ initialRestaurants }: RestaurantManagerProps) {
  const router = useRouter()
  const [restaurants, setRestaurants] = useState(initialRestaurants)
  const [searchQuery, setSearchQuery] = useState('')
  const [isUpdating, setIsUpdating] = useState<string | null>(null)
  const [isDeleting, setIsDeleting] = useState<string | null>(null)
  const [editingRestaurant, setEditingRestaurant] = useState<any | null>(null)

  const filteredRestaurants = restaurants.filter(r => 
    r.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
    r.city.toLowerCase().includes(searchQuery.toLowerCase())
  )

  const toggleStatus = async (id: string, currentStatus: boolean) => {
    try {
      setIsUpdating(id)
      const res = await fetch(`/api/restaurants/${id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ isOpen: !currentStatus })
      })

      if (!res.ok) throw new Error('Failed to update status')

      setRestaurants(restaurants.map(r => 
        r.id === id ? { ...r, isOpen: !currentStatus } : r
      ))
      
      toast.success(currentStatus ? 'Restaurant closed' : 'Restaurant opened')
      router.refresh()
    } catch (error) {
      toast.error('Failed to update restaurant status')
      console.error(error)
    } finally {
      setIsUpdating(null)
    }
  }

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`Are you sure you want to delete ${name}? This action cannot be undone.`)) return

    try {
      setIsDeleting(id)
      const res = await fetch(`/api/restaurants/${id}`, {
        method: 'DELETE',
      })

      if (!res.ok) throw new Error('Failed to delete')

      setRestaurants(restaurants.filter(r => r.id !== id))
      toast.success('Restaurant deleted successfully')
      router.refresh()
    } catch (error) {
      toast.error('Failed to delete restaurant')
      console.error(error)
    } finally {
      setIsDeleting(null)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row gap-4 items-center justify-between bg-card p-4 rounded-2xl border border-border">
        <div className="relative w-full sm:max-w-md">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input 
            placeholder="Search restaurants by name or city..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>
        <Link href="/admin/restaurants/new" className="inline-flex items-center justify-center text-sm font-bold bg-primary hover:bg-primary/90 text-white h-10 px-4 rounded-xl w-full sm:w-auto">
          <Plus className="mr-2 h-4 w-4" />
          Add Restaurant
        </Link>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
        {filteredRestaurants.length === 0 ? (
          <div className="col-span-full py-12 text-center bg-card rounded-2xl border border-border border-dashed">
            <Store className="mx-auto h-12 w-12 text-muted-foreground opacity-50 mb-3" />
            <h3 className="text-lg font-bold text-text-primary">No restaurants found</h3>
            <p className="text-text-secondary mt-1">Try adjusting your search or add a new restaurant.</p>
          </div>
        ) : (
          filteredRestaurants.map(restaurant => (
            <div key={restaurant.id} className="bg-card rounded-2xl border border-border overflow-hidden hover:shadow-md transition-all group flex flex-col">
              <div className="relative h-32 w-full bg-muted">
                {restaurant.bannerUrl ? (
                  <img src={restaurant.bannerUrl} alt={restaurant.name} className="w-full h-full object-cover" />
                ) : (
                  <div className="w-full h-full bg-gradient-to-r from-blue-100 to-indigo-100 dark:from-slate-800 dark:to-slate-700 flex items-center justify-center">
                    <Store className="h-10 w-10 text-muted-foreground opacity-30" />
                  </div>
                )}
                <div className="absolute top-3 right-3 flex gap-2">
                  <Badge variant="outline" className={cn(
                    "font-bold shadow-sm backdrop-blur-md border-0",
                    restaurant.isActive ? "bg-emerald-500/90 text-white" : "bg-zinc-500/90 text-white"
                  )}>
                    {restaurant.isActive ? 'Active' : 'Inactive'}
                  </Badge>
                </div>
                
                {/* Logo overlapping banner */}
                <div className="absolute -bottom-6 left-4">
                  <div className="h-14 w-14 rounded-xl bg-card border-2 border-card shadow-sm overflow-hidden flex items-center justify-center text-2xl">
                    {restaurant.logoUrl ? (
                      <img src={restaurant.logoUrl} alt={restaurant.name} className="w-full h-full object-cover" />
                    ) : (
                      "🍽️"
                    )}
                  </div>
                </div>
              </div>
              
              <div className="p-5 pt-8 flex-1 flex flex-col">
                <div className="flex justify-between items-start mb-1">
                  <h3 className="font-bold text-lg text-text-primary line-clamp-1">{restaurant.name}</h3>
                </div>
                
                <p className="text-xs text-text-secondary flex items-center gap-1 mb-3">
                  <MapPin className="h-3 w-3" />
                  {restaurant.address || restaurant.city}
                </p>
                
                <div className="flex flex-wrap gap-1.5 mb-4">
                  {restaurant.cuisineTags?.map((tag: string, i: number) => (
                    <span key={i} className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 bg-muted text-muted-foreground rounded-full">
                      {tag}
                    </span>
                  ))}
                  {restaurant.isPureVeg && (
                    <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 bg-green-100 dark:bg-green-900/40 text-green-700 dark:text-green-400 rounded-full border border-green-200 dark:border-green-800">
                      Pure Veg
                    </span>
                  )}
                </div>
                
                <div className="mt-auto space-y-3">
                  <div className="flex items-center justify-between text-sm py-2 border-t border-border/50">
                    <span className="flex items-center text-text-secondary gap-1.5"><Package className="h-4 w-4" /> Products</span>
                    <span className="font-bold">{restaurant._count?.products || 0}</span>
                  </div>
                  
                  <div className="flex items-center justify-between text-sm py-2 border-t border-border/50">
                    <span className="flex items-center text-text-secondary gap-1.5"><Clock className="h-4 w-4" /> Delivery</span>
                    <span className="font-bold">{restaurant.deliveryTime}</span>
                  </div>
                  
                  <div className="flex items-center justify-between py-2 border-t border-border/50">
                    <span className="text-sm font-medium text-text-secondary">Accepting Orders</span>
                    <button
                      onClick={() => toggleStatus(restaurant.id, restaurant.isOpen)}
                      disabled={isUpdating === restaurant.id}
                      className={cn(
                        "flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-bold transition-colors",
                        restaurant.isOpen 
                          ? "bg-green-100 text-green-700 hover:bg-green-200 dark:bg-green-900/30 dark:text-green-400" 
                          : "bg-red-100 text-red-700 hover:bg-red-200 dark:bg-red-900/30 dark:text-red-400",
                        isUpdating === restaurant.id && "opacity-50 cursor-not-allowed"
                      )}
                    >
                      {restaurant.isOpen ? (
                        <><ToggleRight className="h-5 w-5" /> Open</>
                      ) : (
                        <><ToggleLeft className="h-5 w-5" /> Closed</>
                      )}
                    </button>
                  </div>
                  
                  <div className="grid grid-cols-2 gap-2 pt-2">
                    <button 
                      type="button"
                      onClick={() => setEditingRestaurant(restaurant)}
                      className="inline-flex items-center justify-center text-sm font-medium border border-input bg-background hover:bg-accent hover:text-accent-foreground h-9 rounded-md px-3 cursor-pointer"
                    >
                      <Edit className="h-4 w-4 mr-2" />
                      Edit
                    </button>
                    <Button 
                      variant="outline" 
                      size="sm" 
                      onClick={() => handleDelete(restaurant.id, restaurant.name)}
                      disabled={isDeleting === restaurant.id}
                      className="w-full text-red-500 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-950 border-red-200 dark:border-red-900"
                    >
                      <Trash2 className="h-4 w-4 mr-2" />
                      {isDeleting === restaurant.id ? 'Deleting...' : 'Delete'}
                    </Button>
                  </div>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Edit Restaurant Modal Overlay (Full-screen native feel on mobile, smooth centered dialog on desktop) */}
      {editingRestaurant && (
        <div className="fixed inset-0 z-50 bg-background sm:bg-black/75 sm:backdrop-blur-md flex flex-col sm:items-center sm:justify-center p-0 sm:p-4 overflow-hidden">
          <div className="bg-card sm:border sm:border-border rounded-none sm:rounded-3xl p-3.5 sm:p-6 max-w-4xl w-full h-full sm:h-auto sm:max-h-[90vh] shadow-2xl relative animate-in fade-in zoom-in-95 flex flex-col overflow-hidden">
            <div className="flex items-center justify-between pb-3 mb-2 border-b border-border relative z-20 shrink-0">
              <div>
                <h2 className="text-base sm:text-xl font-black text-text-primary">Edit {editingRestaurant.name}</h2>
                <p className="text-[10px] sm:text-xs text-text-secondary">Update outlet profile, operating hours & outlet head</p>
              </div>
              <button 
                type="button"
                onClick={() => setEditingRestaurant(null)}
                className="p-2 text-text-secondary hover:text-text-primary rounded-full hover:bg-muted transition-colors cursor-pointer"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
            
            <div className="flex-1 overflow-y-auto px-1 scrollbar-thin">
              <RestaurantForm 
                restaurant={editingRestaurant} 
                onSaved={(updated) => {
                  if (updated) {
                    setRestaurants(restaurants.map(r => r.id === updated.id ? { ...r, ...updated } : r))
                  }
                  setEditingRestaurant(null)
                  router.refresh()
                }}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
