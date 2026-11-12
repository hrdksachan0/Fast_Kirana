import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireVerifiedRole, getEffectiveStoreId } from '@/lib/auth-guard'
import { isRootAdminAccount } from '@/lib/superadmin-config'
import {
  campaignBentoConfigSchema,
  defaultCampaignBentoConfig,
  type CampaignBentoConfig,
} from '@/lib/campaign-bento-config'
import { clearSettingsCache } from '@/lib/settings-cache'
import { revalidateStorefront } from '@/lib/revalidate'
import { cache } from '@/lib/redis-client'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }
const draftKey = (storeId: string | null) =>
  storeId ? `store:${storeId}:campaign_bento_draft` : 'campaign_bento_draft'
const publishedKey = (storeId: string | null) =>
  storeId ? `store:${storeId}:campaign_bento` : 'campaign_bento'

class BentoCampaignRequestError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly issues?: unknown
  ) {
    super(message)
  }
}

function storedBento(value?: string): CampaignBentoConfig | null {
  if (!value) return null
  try {
    const parsed = campaignBentoConfigSchema.safeParse(JSON.parse(value))
    return parsed.success ? parsed.data : null
  } catch {
    return null
  }
}

function validatedBento(value: unknown): CampaignBentoConfig {
  const result = campaignBentoConfigSchema.safeParse(value)
  if (!result.success) {
    throw new BentoCampaignRequestError('Bento campaign configuration is invalid', 422, result.error.issues)
  }
  if (Buffer.byteLength(JSON.stringify(result.data), 'utf8') > 131072) {
    throw new BentoCampaignRequestError('Bento campaign configuration exceeds 128 KB', 422)
  }
  return result.data
}

async function bentoScope(
  session: {
    user?: { role?: string; assignedStoreId?: string | null; email?: string | null; phone?: string | null }
  } | null,
  requested: unknown
) {
  const user = session?.user
  if (!user) throw new BentoCampaignRequestError('Admin login required', 401)
  if (!['ADMIN', 'SUPER_ADMIN'].includes((user.role ?? '').toUpperCase())) {
    throw new BentoCampaignRequestError('Admin access required', 403)
  }
  if (requested !== undefined && requested !== null && typeof requested !== 'string') {
    throw new BentoCampaignRequestError('Invalid storeId', 422)
  }
  const target =
    typeof requested === 'string' && requested && !['all', 'ALL'].includes(requested)
      ? requested.trim()
      : null
  if (target && !/^[A-Za-z0-9_-]{1,128}$/.test(target)) {
    throw new BentoCampaignRequestError('Invalid storeId', 422)
  }
  if (user.assignedStoreId && requested !== undefined && requested !== null && target !== user.assignedStoreId) {
    throw new BentoCampaignRequestError('Access is restricted to your assigned store', 403)
  }
  if (!user.assignedStoreId && !isRootAdminAccount(user)) {
    throw new BentoCampaignRequestError('Global bento campaign access requires a root admin', 403)
  }
  const storeId = getEffectiveStoreId(session, target)
  if (storeId && !(await prisma.darkStore.findUnique({ where: { id: storeId }, select: { id: true } }))) {
    throw new BentoCampaignRequestError('Store not found', 404)
  }
  return storeId
}

function failure(error: unknown) {
  if (error instanceof BentoCampaignRequestError) {
    return NextResponse.json(
      { error: error.message, ...(error.issues ? { issues: error.issues } : {}) },
      { status: error.status, headers }
    )
  }
  console.error('Bento campaign administration failed', error)
  return NextResponse.json({ error: 'Failed to update bento campaign configuration' }, { status: 500, headers })
}

export async function GET(request: NextRequest) {
  const admin = await requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request)
  if (admin.error) return admin.error
  try {
    const storeId = await bentoScope(admin.session, request.nextUrl.searchParams.get('storeId'))
    const keys = [...new Set([draftKey(storeId), publishedKey(storeId), 'campaign_bento'])]
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: keys } },
      select: { key: true, value: true },
    })
    const draft = storedBento(rows.find((row) => row.key === draftKey(storeId))?.value)
    const published =
      storedBento(rows.find((row) => row.key === publishedKey(storeId))?.value) ??
      storedBento(rows.find((row) => row.key === 'campaign_bento')?.value)
    return NextResponse.json({ draft, published }, { headers })
  } catch (error) {
    return failure(error)
  }
}

export async function PUT(request: NextRequest) {
  const admin = await requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request)
  if (admin.error) return admin.error
  let body: unknown
  try {
    body = await request.json()
  } catch {
    return NextResponse.json({ error: 'Malformed JSON request' }, { status: 400, headers })
  }
  try {
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      throw new BentoCampaignRequestError('Request body must be an object', 422)
    }
    const payload = body as Record<string, unknown>
    const action = String(payload.action)
    if (!['save-draft', 'publish', 'disable', 'reset'].includes(action)) {
      throw new BentoCampaignRequestError('action must be save-draft, publish, disable, or reset', 422)
    }
    const storeId = await bentoScope(admin.session, payload.storeId)

    const supplied =
      action === 'disable'
        ? null
        : action === 'reset'
          ? structuredClone(defaultCampaignBentoConfig)
          : validatedBento(payload.campaign)

    const result = await prisma.$transaction(async (tx) => {
      const keys = [...new Set([draftKey(storeId), publishedKey(storeId), 'campaign_bento'])]
      const rows = await tx.storeSetting.findMany({
        where: { key: { in: keys } },
        select: { key: true, value: true },
      })
      let campaign = supplied
      if (action === 'disable') {
        const source =
          rows.find((row) => row.key === publishedKey(storeId)) ??
          rows.find((row) => row.key === 'campaign_bento')
        campaign = storedBento(source?.value)
        if (!campaign) {
          campaign = payload.campaign
            ? validatedBento(payload.campaign)
            : structuredClone(defaultCampaignBentoConfig)
        }
        campaign = { ...campaign, enabled: false }
      }
      if (!campaign) throw new BentoCampaignRequestError('campaign is required', 422)

      const value = JSON.stringify(campaign)
      const upsert = (key: string) =>
        tx.storeSetting.upsert({ where: { key }, update: { value }, create: { key, value } })

      if (action !== 'disable') await upsert(draftKey(storeId))
      if (action !== 'save-draft') await upsert(publishedKey(storeId))

      return {
        draft:
          action === 'disable'
            ? storedBento(rows.find((row) => row.key === draftKey(storeId))?.value)
            : campaign,
        published:
          action === 'save-draft'
            ? storedBento(rows.find((row) => row.key === publishedKey(storeId))?.value)
            : campaign,
      }
    })

    if (action !== 'save-draft') {
      await clearSettingsCache()
      await Promise.allSettled([cache.delByPrefix('campaign_bento:'), cache.delByPrefix('cache:homepage:')])
      revalidateStorefront()
      const base = process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://api.fastkirana.in'
      void fetch(`${base}/api/settings/clear-cache`, {
        method: 'POST',
        signal: AbortSignal.timeout(3000),
      }).catch(() => {})
    }

    return NextResponse.json({ success: true, ...result }, { headers })
  } catch (error) {
    return failure(error)
  }
}
