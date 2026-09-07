import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { SuperAdminDashboard } from '@/components/superadmin/super-admin-dashboard'

export const revalidate = 0

export default async function SuperAdminPage() {
  const session = await auth()
  if (!session) {
    redirect('/login?callbackUrl=/superadmin')
  }

  const role = session.user?.role?.toUpperCase()
  if (role !== 'ADMIN') {
    redirect('/')
  }

  // Super Admin check
  const userEmail = (session.user?.email || '').toLowerCase().trim()
  const userPhone = ((session.user as any)?.phone || '').replace(/\D/g, '').slice(-10)
  const assignedStoreId = (session.user as any)?.assignedStoreId || null

  const isSuperAdmin =
    userEmail === 'superadmin@fastkirana.com' ||
    userEmail.startsWith('superadmin') ||
    userPhone === '9170942500' ||
    (role === 'ADMIN' && !assignedStoreId)

  if (!isSuperAdmin) {
    redirect('/admin')
  }

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl space-y-6 bg-background animate-fade-in">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center border-b border-border/60 pb-4 gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="h-10 w-10 rounded-xl bg-[#e20a22]/10 border border-[#e20a22]/20 flex items-center justify-center">
              <span className="text-lg">🏛️</span>
            </div>
            <div>
              <h1 className="text-xl md:text-2xl font-black text-text-primary tracking-tight">Super Admin HQ</h1>
              <p className="text-xs text-text-secondary mt-0.5">
                Welcome, {session.user.name || 'Super Admin'}. Multi-store operations overview.
              </p>
            </div>
          </div>
        </div>
        <a
          href="/admin"
          className="inline-flex items-center justify-center text-xs font-black uppercase tracking-wider bg-card border border-border/60 text-text-primary h-9 px-4 rounded-xl hover:bg-muted/50 shadow-sm hover:shadow-md transition-all active:scale-[0.98]"
        >
          ← Store Dashboard
        </a>
      </div>

      <SuperAdminDashboard
        serverUser={{
          id: session.user.id,
          name: session.user.name,
          email: session.user.email,
          phone: (session.user as any).phone || null,
        }}
      />
    </div>
  )
}
