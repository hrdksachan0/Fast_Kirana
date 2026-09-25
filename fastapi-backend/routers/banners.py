import json
from fastapi import APIRouter, Depends, HTTPException, status, Response, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import or_, and_, not_
from typing import Optional, List, Dict, Any

from database import get_db
from models import PromoBanner

router = APIRouter(prefix="/banners", tags=["Promotional Banners"])


@router.get("")
async def get_banners(
    response: Response,
    type: Optional[str] = None,
    placement: Optional[str] = None,
    platform: Optional[str] = None,
    storeId: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Get active promotional banners. Supports filtering by type, placement, platform, and storeId.
    Parses JSON metadata stored in banner code string.
    """
    try:
        stmt = select(PromoBanner).where(PromoBanner.isActive == True)

        if type in ["cafe", "food"]:
            stmt = stmt.where(or_(
                PromoBanner.type.in_(["cafe", "food"]),
                PromoBanner.linkUrl.ilike("/restaurant%")
            ))
        elif type in ["brand_offer", "curated_card"]:
            stmt = stmt.where(PromoBanner.type.in_([
                "brand_offer", "curated_card", "dark_showcase", "bento_grid", "editorial"
            ]))
        elif type == "festive":
            stmt = stmt.where(PromoBanner.type == "festive")
        elif type == "grocery":
            stmt = stmt.where(and_(
                not_(PromoBanner.type.in_(["cafe", "food"])),
                not_(PromoBanner.linkUrl.ilike("/restaurant%"))
            ))

        stmt = stmt.order_by(PromoBanner.sortOrder.asc())

        result = await db.execute(stmt)
        banners = result.scalars().all()

        parsed_banners = []
        for b in banners:
            extra = {}
            if b.code and b.code.startswith("{") and b.code.endswith("}"):
                try:
                    extra = json.loads(b.code)
                except Exception:
                    pass

            b_card_type = extra.get("cardType") or b.type or "standard"
            default_placement = "brand_card" if b.type in ["dark_showcase", "bento_grid", "editorial", "brand_offer"] else "hero"
            b_placement = extra.get("placement") or default_placement
            b_platform = extra.get("platform") or "all"
            b_store_id = extra.get("storeId") or extra.get("hubId") or getattr(b, "storeId", None)

            # Filtering checks
            if placement and b_placement != placement and b_placement != "all":
                continue
            if platform and b_platform != platform and b_platform != "all":
                continue
            if storeId and storeId != "all":
                if b_store_id != storeId:
                    continue

            parsed_banners.append({
                "id": b.id,
                "title": b.title,
                "imageUrl": b.imageUrl,
                "linkUrl": b.linkUrl,
                "type": b.type,
                "isActive": b.isActive,
                "sortOrder": b.sortOrder,
                "storeId": b_store_id,
                "code": b.code,
                "rawCode": b.code,
                "couponCode": extra.get("couponCode"),
                "cardType": b_card_type,
                "placement": b_placement,
                "platform": b_platform,
                "tag": extra.get("tag"),
                "subtitle": extra.get("subtitle"),
                "accentColor": extra.get("accentColor"),
            })

        response.headers["Cache-Control"] = "public, s-maxage=60, stale-while-revalidate=120"
        return parsed_banners
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch banners: {str(e)}"
        )
