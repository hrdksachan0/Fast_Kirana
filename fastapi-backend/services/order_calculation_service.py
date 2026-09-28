"""
Order Calculation & State Machine Service
Houses pure, deterministic calculations and state machine validation rules for FastKirana orders.
Fully decoupled from database sessions for clean, fast unit testing.
"""
from typing import Optional, Dict, Any, Tuple


def calculate_coupon_discount(
    coupon_type: str,
    coupon_value: float,
    min_order_value: float,
    subtotal: float,
    max_discount: Optional[float] = None
) -> float:
    """
    Calculate effective coupon discount based on cart subtotal and limits.
    """
    if subtotal <= 0:
        return 0.0
    if subtotal < min_order_value:
        return 0.0

    c_type = (coupon_type or "FLAT").upper().strip()
    if c_type == "PERCENTAGE":
        raw_discount = (subtotal * float(coupon_value)) / 100.0
        if max_discount is not None and max_discount > 0:
            raw_discount = min(raw_discount, float(max_discount))
        return round(min(raw_discount, subtotal), 2)
    
    # FLAT discount
    raw_discount = float(coupon_value)
    return round(min(raw_discount, subtotal), 2)


def calculate_delivery_fee(
    subtotal: float,
    threshold: float,
    base_delivery_fee: float,
    surge_fee: float = 0.0
) -> float:
    """
    Calculate final delivery fee with free delivery threshold and surge charge.
    """
    surge = max(0.0, float(surge_fee))
    base = max(0.0, float(base_delivery_fee))
    thresh = float(threshold)

    if subtotal >= thresh:
        return round(surge, 2)
    return round(base + surge, 2)


def calculate_surge_fee(
    mode: str,
    manual_amount: float = 20.0,
    max_cap: float = 25.0,
    hub_surge_charge: float = 0.0,
    is_raining: bool = False,
    rain_amount: float = 20.0,
    demand_fee: float = 0.0
) -> float:
    """
    Calculate effective surge fee under AUTO, MANUAL_ON, or MANUAL_OFF modes.
    """
    s_mode = (mode or "MANUAL_OFF").upper().strip()
    cap = max(0.0, float(max_cap))

    if s_mode == "MANUAL_OFF":
        return 0.0
    if s_mode == "MANUAL_ON":
        return round(min(max(0.0, float(manual_amount)), cap), 2)

    # AUTO Mode: check hub-level override, then weather, then demand
    if hub_surge_charge > 0:
        return round(min(float(hub_surge_charge), cap), 2)
    if is_raining:
        return round(min(float(rain_amount), cap), 2)
    if demand_fee > 0:
        return round(min(float(demand_fee), cap), 2)

    return 0.0


# ── Strict Order Lifecycle State Machine ──
ALLOWED_STATUS_TRANSITIONS: Dict[str, list[str]] = {
    "ADMIN_PENDING": ["PENDING", "CONFIRMED", "CANCELLED"],
    "PENDING": ["CONFIRMED", "CANCELLED"],
    "CONFIRMED": ["PREPARING", "PACKED", "CANCELLED"],
    "PREPARING": ["PACKED", "CANCELLED"],
    "PACKED": ["SHIPPED", "CANCELLED"],
    "SHIPPED": ["DELIVERED", "CANCELLED"],
    "DELIVERED": [],  # Terminal state
    "CANCELLED": []   # Terminal state
}


def validate_status_transition(current_status: str, target_status: str) -> Tuple[bool, Optional[str]]:
    """
    Enforce state transitions so orders cannot make illogical jumps or revive from terminal states.
    """
    c_status = (current_status or "").upper().strip()
    t_status = (target_status or "").upper().strip()

    if c_status == t_status:
        return True, None

    if c_status in ["DELIVERED", "CANCELLED"]:
        return False, f"Cannot transition order from terminal state '{c_status}' to '{t_status}'."

    allowed = ALLOWED_STATUS_TRANSITIONS.get(c_status, [])
    if t_status not in allowed:
        return False, f"Invalid transition: '{c_status}' cannot transition directly to '{t_status}'."

    return True, None
