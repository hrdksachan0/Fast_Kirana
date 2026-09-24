import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { isRootAdminAccount } from '@/lib/superadmin-config'
import { RestaurantForm } from '@/components/admin/restaurant-form'
import { ChevronLeft } from 'lucide-react'
import Link from 'next/link'

export default async function NewRestaurantPage() {
  const session = await auth()
  if (!session) {
    redirect('/login?callbackUrl=/admin/restaurants/new')
  }

  const dbUser = session?.user?.id ? await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { id: true, role: true, phone: true, email: true, assignedStoreId: true }
  }) : null

  const isMaster = isRootAdminAccount({
    email: dbUser?.email || session.user?.email,
    phone: dbUser?.phone || (session.user as any)?.phone,
    role: dbUser?.role || session.user?.role,
    assignedStoreId: dbUser?.assignedStoreId || (session.user as any)?.assignedStoreId,
  })

  const role = (dbUser?.role || session.user?.role)?.toUpperCase()
  if (!isMaster && role !== 'ADMIN' && role !== 'SUPER_ADMIN' && role !== 'SUPERADMIN') {
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
