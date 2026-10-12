import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireVerifiedRole } from '@/lib/auth-guard'
import { isRootAdminAccount } from '@/lib/superadmin-config'
import { clearSettingsCache } from '@/lib/settings-cache'
import {
  featuredCategoriesKey,
  featuredCategoriesSchema,
  isGroceryCategory,
  parseStoredFeaturedCategories,
} from '@/lib/featured-categories'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }
const key = (storeId: string | null) =>
  storeId ? `store:${storeId}:${featuredCategoriesKey}` : featuredCategoriesKey
class ContentError extends Error {
  constructor(
    message: string,
    readonly status: number
  ) {
    super(message)
  }
}
async function scope(
  user:
    | {
        role?: string
        assignedStoreId?: string | null
        email?: string | null
        phone?: string | null
      }
    | undefined,
  requested: unknown
) {
  if (!user) throw new ContentError('Admin login required', 401)
  if (requested != null && typeof requested !== 'string')
    throw new ContentError('Invalid storeId', 422)
  const target =
    typeof requested === 'string' && !['', 'all', 'ALL'].includes(requested)
      ? requested.trim()
      : null
  if (target && !/^[A-Za-z0-9_-]{1,128}$/.test(target))
    throw new ContentError('Invalid storeId', 422)
  if (user.assignedStoreId && requested != null && target !== user.assignedStoreId)
    throw new ContentError('Access is restricted to your assigned store', 403)
  if (!user.assignedStoreId && !isRootAdminAccount(user))
    throw new ContentError('Global content access requires a root admin', 403)
  const storeId = user.assignedStoreId || target
  if (
    storeId &&
    !(await prisma.darkStore.findUnique({ where: { id: storeId }, select: { id: true } }))
  )
    throw new ContentError('Store not found', 404)
  return storeId
}
function failure(error: unknown) {
  if (error instanceof ContentError)
    return NextResponse.json({ error: error.message }, { status: error.status, headers })
  console.error('Featured category settings failed', error)
  return NextResponse.json(
    { error: 'Unable to save featured categories' },
    { status: 500, headers }
  )
}
export async function GET(request: NextRequest) {
  const admin = await requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request)
  if (admin.error) return admin.error
  try {
    const storeId = await scope(admin.session?.user, request.nextUrl.searchParams.get('storeId'))
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [key(storeId), featuredCategoriesKey] } },
      select: { key: true, value: true },
    })
    const own = rows.find((row) => row.key === key(storeId))
    return NextResponse.json(
      {
        config: parseStoredFeaturedCategories(
          own?.value ?? rows.find((row) => row.key === featuredCategoriesKey)?.value
        ),
        inherited: Boolean(storeId && !own),
      },
      { headers }
    )
  } catch (error) {
    return failure(error)
  }
}
export async function PUT(request: NextRequest) {
  const admin = await requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request)
  if (admin.error) return admin.error
  let payload: unknown
  try {
    payload = await request.json()
  } catch {
    return NextResponse.json({ error: 'Malformed JSON request' }, { status: 400, headers })
  }
  try {
    if (!payload || typeof payload !== 'object' || Array.isArray(payload))
      throw new ContentError('Request body must be an object', 422)
    const body = payload as Record<string, unknown>
    const storeId = await scope(admin.session?.user, body.storeId)
    const parsed = featuredCategoriesSchema.safeParse(body.config)
    if (!parsed.success)
      return NextResponse.json(
        { error: 'Featured categories are invalid', issues: parsed.error.issues },
        { status: 422, headers }
      )
    const ids = parsed.data.items.map((item) => item.categoryId)
    const categories = await prisma.category.findMany({
      where: { id: { in: ids } },
      select: { id: true, name: true, slug: true, parentId: true },
    })
    if (
      ids.some(
        (id) => !categories.some((category) => category.id === id && isGroceryCategory(category))
      )
    )
      throw new ContentError('Choose existing grocery parent categories', 422)
    const value = JSON.stringify(parsed.data)
    await prisma.storeSetting.upsert({
      where: { key: key(storeId) },
      update: { value },
      create: { key: key(storeId), value },
    })
    await clearSettingsCache()
    const base = process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://api.fastkirana.in'
    void fetch(`${base}/api/settings/clear-cache`, {
      method: 'POST',
      signal: AbortSignal.timeout(3000),
    }).catch(() => {})
    return NextResponse.json({ success: true, config: parsed.data, inherited: false }, { headers })
  } catch (error) {
    return failure(error)
  }
}
