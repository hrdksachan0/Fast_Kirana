from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from ..core.database import get_db
from ..models.restaurant import Restaurant
from ..schemas.restaurant import RestaurantOut

router = APIRouter(prefix="/restaurants", tags=["Restaurants"])

@router.get("", response_model=List[RestaurantOut])
def get_restaurants(
    cuisine: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(Restaurant).filter(Restaurant.isActive == True)
    if search:
        search_fmt = f"%{search.lower()}%"
        query = query.filter(Restaurant.name.ilike(search_fmt))
    
    restaurants = query.order_by(Restaurant.sortOrder.asc()).all()
    return restaurants

@router.get("/{id_or_slug}", response_model=RestaurantOut)
def get_restaurant(id_or_slug: str, db: Session = Depends(get_db)):
    restaurant = db.query(Restaurant).filter(
        (Restaurant.id == id_or_slug) | (Restaurant.slug == id_or_slug.lower())
    ).first()
    if not restaurant:
        raise HTTPException(status_code=404, detail="Restaurant not found")
    return restaurant
