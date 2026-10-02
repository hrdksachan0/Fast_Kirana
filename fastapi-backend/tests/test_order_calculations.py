import pytest
from services.order_calculation_service import (
    calculate_coupon_discount,
    calculate_delivery_fee,
    calculate_surge_fee,
    validate_status_transition,
)
from services.task_queue import enqueue_background_task
from fastapi import BackgroundTasks


# ── 1. Coupon Discount Tests ──────────────────────────────────────────────────

def test_coupon_flat_discount_below_min_order():
    # Subtotal 150 < min_order_value 200 -> discount must be 0
    discount = calculate_coupon_discount(
        coupon_type="FLAT",
        coupon_value=50.0,
        min_order_value=200.0,
        subtotal=150.0
    )
    assert discount == 0.0


def test_coupon_flat_discount_valid():
    discount = calculate_coupon_discount(
        coupon_type="FLAT",
        coupon_value=50.0,
        min_order_value=200.0,
        subtotal=250.0
    )
    assert discount == 50.0


def test_coupon_percentage_without_max_cap():
    # 20% on 500 = 100
    discount = calculate_coupon_discount(
        coupon_type="PERCENTAGE",
        coupon_value=20.0,
        min_order_value=200.0,
        subtotal=500.0
    )
    assert discount == 100.0


def test_coupon_percentage_with_max_cap():
    # 20% on 500 = 100, but cap is 60 -> discount must be 60
    discount = calculate_coupon_discount(
        coupon_type="PERCENTAGE",
        coupon_value=20.0,
        min_order_value=200.0,
        subtotal=500.0,
        max_discount=60.0
    )
    assert discount == 60.0


def test_coupon_discount_never_exceeds_subtotal():
    # Flat 100 discount on 60 order -> discount cannot exceed 60
    discount = calculate_coupon_discount(
        coupon_type="FLAT",
        coupon_value=100.0,
        min_order_value=50.0,
        subtotal=60.0
    )
    assert discount == 60.0


def test_coupon_zero_or_negative_subtotal():
    assert calculate_coupon_discount("FLAT", 50.0, 0.0, 0.0) == 0.0
    assert calculate_coupon_discount("FLAT", 50.0, 0.0, -10.0) == 0.0


# ── 2. Delivery Fee & Threshold Tests ─────────────────────────────────────────

def test_delivery_fee_under_threshold():
    # Subtotal 150 < 200 threshold -> base fee 25
    fee = calculate_delivery_fee(
        subtotal=150.0,
        threshold=200.0,
        base_delivery_fee=25.0
    )
    assert fee == 25.0


def test_delivery_fee_at_or_above_threshold():
    # Subtotal 200 >= 200 threshold -> delivery fee becomes 0
    fee = calculate_delivery_fee(
        subtotal=200.0,
        threshold=200.0,
        base_delivery_fee=25.0
    )
    assert fee == 0.0

    fee_above = calculate_delivery_fee(
        subtotal=500.0,
        threshold=200.0,
        base_delivery_fee=25.0
    )
    assert fee_above == 0.0


def test_delivery_fee_with_surge_charge():
    # When free delivery applies, surge charge is still charged
    fee_free_with_surge = calculate_delivery_fee(
        subtotal=300.0,
        threshold=200.0,
        base_delivery_fee=25.0,
        surge_fee=15.0
    )
    assert fee_free_with_surge == 15.0

    # Under threshold: base fee + surge
    fee_under_with_surge = calculate_delivery_fee(
        subtotal=100.0,
        threshold=200.0,
        base_delivery_fee=25.0,
        surge_fee=15.0
    )
    assert fee_under_with_surge == 40.0


# ── 3. Surge Fee Evaluation Tests ─────────────────────────────────────────────

def test_surge_fee_manual_off():
    surge = calculate_surge_fee(mode="MANUAL_OFF", manual_amount=30.0)
    assert surge == 0.0


def test_surge_fee_manual_on_capped():
    # Manual 30 capped at max_cap 25
    surge = calculate_surge_fee(mode="MANUAL_ON", manual_amount=30.0, max_cap=25.0)
    assert surge == 25.0


def test_surge_fee_auto_rain_detected():
    surge = calculate_surge_fee(
        mode="AUTO",
        is_raining=True,
        rain_amount=20.0,
        max_cap=25.0
    )
    assert surge == 20.0


def test_surge_fee_auto_hub_override():
    # Hub override takes priority over rain
    surge = calculate_surge_fee(
        mode="AUTO",
        hub_surge_charge=15.0,
        is_raining=True,
        rain_amount=20.0,
        max_cap=25.0
    )
    assert surge == 15.0


def test_surge_fee_auto_clear_weather():
    surge = calculate_surge_fee(
        mode="AUTO",
        is_raining=False,
        hub_surge_charge=0.0,
        demand_fee=0.0
    )
    assert surge == 0.0


# ── 4. Order State Machine Transition Tests ───────────────────────────────────

def test_state_machine_valid_linear_flow():
    # Valid flow: PENDING -> CONFIRMED -> PREPARING -> PACKED -> SHIPPED -> DELIVERED
    flow = [
        ("PENDING", "CONFIRMED"),
        ("CONFIRMED", "PREPARING"),
        ("PREPARING", "PACKED"),
        ("PACKED", "SHIPPED"),
        ("SHIPPED", "DELIVERED"),
    ]
    for current, target in flow:
        is_valid, err = validate_status_transition(current, target)
        assert is_valid is True, f"Failed on {current} -> {target}: {err}"
        assert err is None


def test_state_machine_same_status_idempotent():
    is_valid, err = validate_status_transition("CONFIRMED", "CONFIRMED")
    assert is_valid is True
    assert err is None


def test_state_machine_rider_pickup_transitions():
    # Food/Express orders: Rider can pick up food directly from kitchen
    is_valid_confirmed, err1 = validate_status_transition("CONFIRMED", "SHIPPED")
    assert is_valid_confirmed is True
    assert err1 is None

    is_valid_preparing, err2 = validate_status_transition("PREPARING", "SHIPPED")
    assert is_valid_preparing is True
    assert err2 is None


def test_state_machine_invalid_jumps():
    # Cannot jump from PENDING directly to DELIVERED
    is_valid, err = validate_status_transition("PENDING", "DELIVERED")
    assert is_valid is False
    assert "Invalid transition" in err


def test_state_machine_terminal_state_delivered_locked():
    # Delivered orders cannot be changed
    is_valid, err = validate_status_transition("DELIVERED", "CANCELLED")
    assert is_valid is False
    assert "terminal state" in err


def test_state_machine_terminal_state_cancelled_locked():
    # Cancelled orders cannot be resurrected
    is_valid, err = validate_status_transition("CANCELLED", "PENDING")
    assert is_valid is False
    assert "terminal state" in err


# ── 5. Background Task Queue Tests ────────────────────────────────────────────

def test_task_queue_enqueue_safely():
    executed = []

    def sample_task(x: int):
        executed.append(x)

    bg = BackgroundTasks()
    success = enqueue_background_task(bg, sample_task, 42)
    assert success is True
    assert len(bg.tasks) == 1
