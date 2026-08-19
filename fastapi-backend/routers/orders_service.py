"""
Order Service Utilities & Helper Functions
Extracted from orders.py for modularity and clean architecture.
"""

import math
import uuid
import logging
from typing import Dict, Any, Optional
from datetime import datetime

logger = logging.getLogger("orders_service")


def generate_id(prefix: str = "ord_") -> str:
    """Generate a unique ID string."""
    return f"{prefix}{uuid.uuid4().hex[:20]}"


def get_last_10_digits(phone: str) -> str:
    """Extract clean 10-digit mobile number."""
    digits = "".join(c for c in str(phone) if c.isdigit())
    return digits[-10:] if len(digits) >= 10 else digits


def get_distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calculate Haversine distance in kilometers between two GPS coordinates."""
    R = 6371.0  # Earth radius in km
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (math.sin(d_lat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         (math.sin(d_lng / 2.0) ** 2))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


def validate_order_status_transition(current_status: str, target_status: str) -> bool:
    """Validate allowed state transitions for order workflow."""
    allowed_map = {
        "PENDING": ["CONFIRMED", "CANCELLED"],
        "CONFIRMED": ["PACKED", "CANCELLED"],
        "PACKED": ["SHIPPED", "CANCELLED"],
        "SHIPPED": ["DELIVERED", "CANCELLED"],
        "DELIVERED": [],
        "CANCELLED": []
    }
    allowed = allowed_map.get(str(current_status).upper(), [])
    return str(target_status).upper() in allowed
