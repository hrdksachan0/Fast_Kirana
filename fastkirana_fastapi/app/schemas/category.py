from pydantic import BaseModel, ConfigDict
from typing import Optional

class CategoryOut(BaseModel):
    id: str
    name: str
    slug: str
    imageUrl: Optional[str] = None
    parentId: Optional[str] = None
    sortOrder: int = 0

    model_config = ConfigDict(from_attributes=True)
