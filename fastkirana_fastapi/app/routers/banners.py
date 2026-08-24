from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from typing import List
from ..core.database import get_db
from ..models.banner import PromoBanner
from ..schemas.banner import PromoBannerOut

router = APIRouter(prefix="/banners", tags=["Banners"])

@router.get("", response_model=List[PromoBannerOut])
def get_banners(db: Session = Depends(get_db)):
    banners = db.query(PromoBanner).filter(PromoBanner.isActive == True).order_by(PromoBanner.sortOrder.asc()).all()
    return banners
