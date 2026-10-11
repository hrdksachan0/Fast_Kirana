import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { requireVerifiedRole, getEffectiveStoreId } from '@/lib/auth-guard'
import { isRootAdminAccount } from '@/lib/superadmin-config'
import { campaignSchema, type CampaignConfig } from '@/lib/campaign-config'
import { clearSettingsCache } from '@/lib/settings-cache'
import { revalidateStorefront } from '@/lib/revalidate'
import { cache } from '@/lib/redis-client'

export const dynamic = 'force-dynamic'
const headers = { 'Cache-Control': 'no-store, max-age=0' }
const draftKey = (storeId: string | null) => storeId ? `store:${storeId}:homepage_campaign_draft` : 'homepage_campaign_draft'
const publishedKey = (storeId: string | null) => storeId ? `store:${storeId}:homepage_campaign` : 'homepage_campaign'

class CampaignRequestError extends Error {
  constructor(message: string, readonly status: number, readonly issues?: unknown) { super(message) }
}

function storedCampaign(value?: string): CampaignConfig | null {
  if (!value) return null
  try {
    const parsed = campaignSchema.safeParse(JSON.parse(value))
    return parsed.success ? parsed.data : null
  } catch { return null }
}

function validatedCampaign(value: unknown): CampaignConfig {
  const result = campaignSchema.safeParse(value)
  if (!result.success) throw new CampaignRequestError('Campaign configuration is invalid', 422, result.error.issues)
  if (Buffer.byteLength(JSON.stringify(result.data), 'utf8') > 131072) {
    throw new CampaignRequestError('Campaign configuration exceeds 128 KB', 422)
  }
  return result.data
}

async function campaignScope(session: { user?: { role?: string; assignedStoreId?: string | null; email?: string | null; phone?: string | null } } | null, requested: unknown) {
  const user = session?.user
  if (!user) throw new CampaignRequestError('Admin login required', 401)
  if (!['ADMIN', 'SUPER_ADMIN'].includes((user.role ?? '').toUpperCase())) throw new CampaignRequestError('Admin access required', 403)
  if (requested !== undefined && requested !== null && typeof requested !== 'string') throw new CampaignRequestError('Invalid storeId', 422)
  const target = typeof requested === 'string' && requested && !['all', 'ALL'].includes(requested) ? requested.trim() : null
  if (target && !/^[A-Za-z0-9_-]{1,128}$/.test(target)) throw new CampaignRequestError('Invalid storeId', 422)
  if (user.assignedStoreId && requested !== undefined && requested !== null && target !== user.assignedStoreId) {
    throw new CampaignRequestError('Access is restricted to your assigned store', 403)
  }
  if (!user.assignedStoreId && !isRootAdminAccount(user)) throw new CampaignRequestError('Global campaign access requires a root admin', 403)
  const storeId = getEffectiveStoreId(session, target)
  if (storeId && !await prisma.darkStore.findUnique({ where: { id: storeId }, select: { id: true } })) {
    throw new CampaignRequestError('Store not found', 404)
  }
  return storeId
}

function failure(error: unknown) {
  if (error instanceof CampaignRequestError) return NextResponse.json({ error: error.message, ...(error.issues ? { issues: error.issues } : {}) }, { status: error.status, headers })
  console.error('Campaign administration failed', error)
  return NextResponse.json({ error: 'Failed to update campaign configuration' }, { status: 500, headers })
}

export async function GET(request: NextRequest) {
  const admin = await requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request)
  if (admin.error) return admin.error
  try {
    const storeId = await campaignScope(admin.session, request.nextUrl.searchParams.get('storeId'))
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [draftKey(storeId), publishedKey(storeId)] } }, select: { key: true, value: true },
    })
    return NextResponse.json({
      draft: storedCampaign(rows.find(row => row.key === draftKey(storeId))?.value),
      published: storedCampaign(rows.find(row => row.key === publishedKey(storeId))?.value),
    }, { headers })
  } catch (error) { return failure(error) }
}

export async function PUT(request: NextRequest) {
  const admin = await requireVerifiedRole(['ADMIN', 'SUPER_ADMIN'], request)
  if (admin.error) return admin.error
  let body: unknown
  try { body = await request.json() } catch { return NextResponse.json({ error: 'Malformed JSON request' }, { status: 400, headers }) }
  try {
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new CampaignRequestError('Request body must be an object', 422)
    const payload = body as Record<string, unknown>
    if (!['save-draft', 'publish', 'disable'].includes(String(payload.action))) throw new CampaignRequestError('action must be save-draft, publish, or disable', 422)
    const storeId = await campaignScope(admin.session, payload.storeId)
    const supplied = payload.action === 'disable' ? null : validatedCampaign(payload.campaign)
    const result = await prisma.$transaction(async tx => {
      const keys = [...new Set([draftKey(storeId), publishedKey(storeId), 'homepage_campaign'])]
      const rows = await tx.storeSetting.findMany({ where: { key: { in: keys } }, select: { key: true, value: true } })
      let campaign = supplied
      if (payload.action === 'disable') {
        const source = rows.find(row => row.key === publishedKey(storeId)) ?? rows.find(row => row.key === 'homepage_campaign')
        campaign = storedCampaign(source?.value)
        if (!campaign) {
          if (!payload.campaign) throw new CampaignRequestError('No published campaign to disable', 400)
          campaign = validatedCampaign(payload.campaign)
        }
        campaign = { ...campaign, enabled: false }
      }
      if (!campaign) throw new CampaignRequestError('campaign is required', 422)
      const value = JSON.stringify(campaign)
      const upsert = (key: string) => tx.storeSetting.upsert({ where: { key }, update: { value }, create: { key, value } })
      if (payload.action !== 'disable') await upsert(draftKey(storeId))
      if (payload.action !== 'save-draft') await upsert(publishedKey(storeId))
      return {
        draft: payload.action === 'disable' ? storedCampaign(rows.find(row => row.key === draftKey(storeId))?.value) : campaign,
        published: payload.action === 'save-draft' ? storedCampaign(rows.find(row => row.key === publishedKey(storeId))?.value) : campaign,
      }
    })
    if (payload.action !== 'save-draft') {
      await clearSettingsCache()
      await Promise.allSettled([cache.delByPrefix('homepage_campaign:'), cache.delByPrefix('cache:homepage:')])
      revalidateStorefront()
      // The FastAPI campaign read is no-store. Clear its legacy settings cache
      // through the same existing cache endpoints used by settings changes.
      const base = process.env.NEXT_PUBLIC_FASTAPI_URL || 'https://api.fastkirana.in'
      void fetch(`${base}/api/settings/clear-cache`, { method: 'POST', signal: AbortSignal.timeout(3000) }).catch(() => {})
    }
    return NextResponse.json({ success: true, ...result }, { headers })
  } catch (error) { return failure(error) }
}
