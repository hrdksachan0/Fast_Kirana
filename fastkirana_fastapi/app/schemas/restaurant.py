from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Any

class RestaurantOut(BaseModel):
    id: str
    name: str
    slug: str
    description: Optional[str] = None
    logoUrl: Optional[str] = None
    bannerUrl: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    cuisineTags: List[str] = []
    rating: float = 4.5
    reviewCount: int = 0
    deliveryTime: str = "25-30 min"
    distance: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None
    isVeg: bool = False
    isPureVeg: bool = False
    isOpen: bool = True
    openTime: Optional[str] = None
    closeTime: Optional[str] = None
    discountOffer: Optional[str] = None
    discountBadge: Optional[str] = None
    menuSections: Optional[Any] = None

    model_config = ConfigDict(from_attributes=True)
