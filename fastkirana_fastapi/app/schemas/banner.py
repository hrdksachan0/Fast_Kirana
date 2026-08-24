from pydantic import BaseModel, ConfigDict
from typing import Optional

class PromoBannerOut(BaseModel):
    id: str
    title: str
    description: str
    code: str
    gradient: str = "from-primary via-rose-500 to-orange-400"
    type: str = "custom"
    imageUrl: Optional[str] = None
    linkUrl: Optional[str] = None
    isActive: bool = True
    sortOrder: int = 0

    model_config = ConfigDict(from_attributes=True)
