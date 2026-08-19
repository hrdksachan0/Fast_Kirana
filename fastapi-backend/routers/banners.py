from fastapi import APIRouter, Depends, HTTPException, status, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import Optional

from database import get_db
from models import PromoBanner

router = APIRouter(prefix="/banners", tags=["Promotional Banners"])


@router.get("")
async def get_banners(
    response: Response,
    type: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Get active promotional banners. Filters based on 'type' ('cafe' or 'grocery').
    """
    try:
        stmt = select(PromoBanner).where(PromoBanner.isActive == True)

        if type == "cafe":
            stmt = stmt.where(PromoBanner.type == "cafe")
        elif type == "grocery":
            stmt = stmt.where(PromoBanner.type != "cafe")

        stmt = stmt.order_by(PromoBanner.sortOrder.asc())

        result = await db.execute(stmt)
        banners = result.scalars().all()

        response.headers["Cache-Control"] = "public, s-maxage=60, stale-while-revalidate=120"
        return banners
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch banners: {str(e)}"
        )
