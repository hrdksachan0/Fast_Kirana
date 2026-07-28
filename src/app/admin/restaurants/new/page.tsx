import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { RestaurantForm } from '@/components/admin/restaurant-form'
import { ChevronLeft } from 'lucide-react'
import Link from 'next/link'

export default async function NewRestaurantPage() {
  const session = await auth()
  if (!session || session.user?.role !== 'ADMIN') {
    redirect('/')
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl animate-fade-in">
      <div className="mb-6 flex items-center gap-4">
        <Link 
          href="/admin/restaurants"
          className="flex h-10 w-10 items-center justify-center rounded-full bg-card border border-border hover:bg-accent hover:text-accent-foreground transition-colors"
        >
          <ChevronLeft className="h-5 w-5" />
        </Link>
        <div>
          <h1 className="text-2xl font-black text-text-primary tracking-tight">Add New Restaurant</h1>
          <p className="text-sm text-text-secondary mt-1">Create a new restaurant profile and settings.</p>
        </div>
      </div>
      
      <RestaurantForm />
    </div>
  )
}
