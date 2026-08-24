from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Any
from .category import CategoryOut

class ProductVariant(BaseModel):
    name: str
    price: float
    mrp: Optional[float] = None

class ProductOut(BaseModel):
    id: str
    name: str
    slug: str
    description: Optional[str] = None
    imageUrl: Optional[str] = None
    categoryId: str
    restaurantId: Optional[str] = None
    mrp: float
    price: float
    discount: float = 0.0
    unit: str
    stock: int = 0
    isAvailable: bool = True
    tags: List[str] = []
    variants: Optional[Any] = None
    isFlashDeal: bool = False
    isTopPick: bool = False
    isBestSeller: bool = False
    sortOrder: int = 0
    category: Optional[CategoryOut] = None

    model_config = ConfigDict(from_attributes=True)
