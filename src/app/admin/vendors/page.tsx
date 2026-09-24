import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { prisma } from '@/lib/prisma'
import { isRootAdminAccount } from '@/lib/superadmin-config'
import { AdminVendorConsole } from '@/components/admin/admin-vendor-console'

export const revalidate = 0

export default async function AdminVendorsPage(props: {
  searchParams?: Promise<{ storeId?: string }>
}) {
  const session = await auth()
  if (!session) {
    redirect('/login?callbackUrl=/admin/vendors')
  }

  const dbUser = session?.user?.id ? await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { id: true, role: true, phone: true, email: true, assignedStoreId: true }
  }) : null

  const userAssignedStoreId = dbUser?.assignedStoreId || (session.user as any)?.assignedStoreId || null

  const isMaster = isRootAdminAccount({
    email: dbUser?.email || session.user?.email,
    phone: dbUser?.phone || (session.user as any)?.phone,
    role: dbUser?.role || session.user?.role,
    assignedStoreId: userAssignedStoreId,
  })

  const role = (dbUser?.role || session.user?.role)?.toUpperCase()
  if (!isMaster && role !== 'ADMIN' && role !== 'SUPER_ADMIN' && role !== 'SUPERADMIN') {
    redirect('/')
  }

  const searchParams = props.searchParams ? await props.searchParams : undefined
  const storeId = searchParams?.storeId || undefined

  return (
    <div className="container mx-auto px-4 py-8 max-w-7xl animate-fade-in">
      <AdminVendorConsole storeId={storeId} />
    </div>
  )
}
