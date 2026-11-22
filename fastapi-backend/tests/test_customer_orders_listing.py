import pytest
from unittest.mock import AsyncMock, MagicMock
from routers.orders import list_orders
from models import Order, OrderStatus

@pytest.mark.asyncio
async def test_list_orders_combined_status_does_not_crash_on_all():
    """
    Regression test: ensures list_orders does not shadow builtin all()
    which previously raised TypeError: 'bool' object is not callable
    when combining multi-outlet order statuses.
    """
    mock_db = AsyncMock()
    mock_res = MagicMock()

    # Simulate 2 sub-orders belonging to one combined checkout
    order1 = MagicMock(spec=Order)
    order1.id = "ord_sub1"
    order1.readableId = "4349-G"
    order1.combinedId = "comb_1"
    order1.status = OrderStatus.DELIVERED
    order1.orderType = "GROCERY"
    order1.subtotal = 100.0
    order1.discount = 0.0
    order1.deliveryFee = 20.0
    order1.taxes = 5.0
    order1.miscFee = 0.0
    order1.total = 125.0
    order1.paymentMethod = "COD"
    order1.paymentStatus = "PAID"
    order1.deliveryMethod = "DELIVERY"
    order1.createdAt = None
    order1.shopName = "Dark Store"
    order1.restaurantId = None
    order1.items = []
    order1.address = None

    order2 = MagicMock(spec=Order)
    order2.id = "ord_sub2"
    order2.readableId = "4349-R"
    order2.combinedId = "comb_1"
    order2.status = OrderStatus.DELIVERED
    order2.orderType = "RESTAURANT"
    order2.subtotal = 50.0
    order2.discount = 0.0
    order2.deliveryFee = 0.0
    order2.taxes = 5.0
    order2.miscFee = 0.0
    order2.total = 55.0
    order2.paymentMethod = "COD"
    order2.paymentStatus = "PAID"
    order2.deliveryMethod = "DELIVERY"
    order2.createdAt = None
    order2.shopName = "A.S. Restaurant"
    order2.restaurantId = "REST-101"
    order2.items = []
    order2.address = None

    mock_res.scalars.return_value.all.return_value = [order1, order2]
    mock_db.execute.return_value = mock_res

    current_user = {
        "id": "user_123",
        "role": "CUSTOMER",
        "phone": "+916306623339",
        "email": None
    }

    # Calling list_orders must succeed and NOT throw TypeError: 'bool' object is not callable
    orders = await list_orders(
        is_all=False,
        storeId=None,
        userId="user_123",
        phone="6306623339",
        current_user=current_user,
        db=mock_db
    )

    assert len(orders) == 1
    assert orders[0]["isCombined"] is True
    assert orders[0]["status"] == "DELIVERED"
    assert orders[0]["readableId"] == "4349"
    assert orders[0]["total"] == 180.0
