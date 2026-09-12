import { redirect } from 'next/navigation'
import { auth } from '@/auth'
import { AdminVendorConsole } from '@/components/admin/admin-vendor-console'

export const revalidate = 0

export default async function AdminVendorsPage(props: {
  searchParams?: Promise<{ storeId?: string }>
}) {
  const session = await auth()
  if (!session || session.user?.role !== 'ADMIN') {
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
