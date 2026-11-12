import { NextRequest, NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import {
  campaignBentoConfigSchema,
  collectBentoProductIds,
  defaultCampaignBentoConfig,
  isBentoCardVisible,
} from '@/lib/campaign-bento-config'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  const requested = request.nextUrl.searchParams.get('storeId')
  const includeHidden = request.nextUrl.searchParams.get('includeHidden') === 'true'
  const headers = includeHidden
    ? { 'Cache-Control': 'no-store, max-age=0' }
    : { 'Cache-Control': 'public, s-maxage=10, stale-while-revalidate=50' }
  const storeId =
    requested && requested !== 'all' && requested !== 'ALL' ? requested.trim() : null
  if (storeId && !/^[A-Za-z0-9_-]{1,128}$/.test(storeId)) {
    return NextResponse.json({ error: 'Invalid storeId' }, { status: 422, headers })
  }

  try {
    const key = storeId ? `store:${storeId}:campaign_bento` : 'campaign_bento'
    const rows = await prisma.storeSetting.findMany({
      where: { key: { in: [...new Set([key, 'campaign_bento'])] } },
      select: { key: true, value: true },
    })

    const row = rows.find((value) => value.key === key) ?? rows.find((value) => value.key === 'campaign_bento')
    let config = structuredClone(defaultCampaignBentoConfig)
    if (row?.value) {
      try {
        const parsed = campaignBentoConfigSchema.safeParse(JSON.parse(row.value))
        if (parsed.success) {
          config = parsed.data
        }
      } catch {
        // Fallback to default config if stored row is malformed
      }
    }

    const effectiveStoreId = storeId || 'hub-209206'
    const linkedIds = collectBentoProductIds(config)
    const linkedRaw =
      linkedIds.length > 0
        ? await prisma.product.findMany({
            where: {
              id: { in: linkedIds },
              restaurantId: null,
            },
            include: {
              category: true,
              inventories: {
                where: { storeId: effectiveStoreId },
                select: { stock: true, isAvailable: true, priceOverride: true },
              },
            },
          })
        : []

    const linkedProducts = linkedRaw.map((p) => {
      const inv = p.inventories?.[0]
      const stock = inv ? inv.stock : p.stock
      const isAvailable = inv ? inv.isAvailable && stock > 0 : p.isAvailable && stock > 0
      const price =
        inv?.priceOverride !== null && inv?.priceOverride !== undefined
          ? inv.priceOverride
          : p.price
      const discount =
        p.mrp > price ? Math.max(0, Math.round(((p.mrp - price) / p.mrp) * 100)) : p.discount
      return {
        id: p.id,
        name: p.name,
        slug: p.slug,
        description: p.description,
        imageUrl: p.imageUrl,
        categoryId: p.categoryId,
        restaurantId: p.restaurantId,
        mrp: p.mrp,
        price,
        discount,
        unit: p.unit,
        stock,
        isAvailable,
        tags: p.tags,
        variants: p.variants,
        category: p.category,
      }
    })

    // Map availability for inventory-based visibility checks
    const productAvailMap = new Map<string, boolean>()
    for (const p of linkedProducts) {
      productAvailMap.set(p.id, Boolean(p.isAvailable && p.stock > 0))
    }

    const evalCard = <T extends { enabled: boolean }>(
      card: T,
      items: { productId?: string | null }[]
    ) => {
      let inStockCount = 0
      for (const item of items) {
        if (!item.productId) {
          inStockCount += 1 // unlinked fallback item counts as available
        } else if (productAvailMap.get(item.productId)) {
          inStockCount += 1
        }
      }
      const check = isBentoCardVisible(card as any, {
        inStockCount,
        currentStoreId: effectiveStoreId,
      })

      return {
        ...card,
        // If includeHidden is true (e.g. for admin previews), keep original card.enabled
        enabled: includeHidden ? card.enabled : check.isVisible,
        isRuleActive: check.isVisible,
        visibilityReason: check.reason ?? null,
        inStockItemsCount: inStockCount,
      }
    }

    // Process all cards through real inventory and schedule rules
    const processedCampaign = {
      ...config,
      freshMarket: evalCard(
        config.freshMarket,
        config.freshMarket.tabs.flatMap((t) => t.items)
      ),
      dailyRestock: evalCard(config.dailyRestock, config.dailyRestock.items),
      valuePicks: evalCard(config.valuePicks, config.valuePicks.items),
      giftingBoutique: evalCard(config.giftingBoutique, [
        config.giftingBoutique.heroItem,
        config.giftingBoutique.miniItem,
      ]),
      movieNight: evalCard(config.movieNight, config.movieNight.items),
      breakfastClub: evalCard(config.breakfastClub, config.breakfastClub.items),
    }

    return NextResponse.json({ campaign: processedCampaign, linkedProducts }, { headers })
  } catch (error) {
    console.error('Failed to load bento campaign configuration', error)
    return NextResponse.json(
      { error: 'Failed to load bento campaign configuration' },
      { status: 500, headers }
    )
  }
}
