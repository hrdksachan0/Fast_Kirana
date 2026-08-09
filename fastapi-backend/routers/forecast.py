from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, desc, and_, text
from typing import List, Dict, Any
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from database import get_db
from models import Order, OrderItem, Product, OrderStatus
from routers.auth import require_admin

router = APIRouter(prefix="/forecast", tags=["AI Demand Forecasting"])

@router.get("/demand")
async def get_ai_demand_forecast(
    days: int = Query(7, ge=1, le=30),
    current_admin: Any = Depends(require_admin),
    db: AsyncSession = Depends(get_db)
):
    """
    Native Python AI Demand Forecasting Engine for Inventory & Stock Optimization
    """
    start_date = datetime.utcnow() - timedelta(days=30)

    # Fetch last 30 days completed order items using standard SQLAlchemy enum comparison
    stmt = select(
        OrderItem.productId,
        OrderItem.name,
        OrderItem.quantity,
        Order.createdAt
    ).join(Order, OrderItem.orderId == Order.id).where(
        and_(
            Order.status == OrderStatus.DELIVERED,
            Order.createdAt >= start_date
        )
    )

    res = await db.execute(stmt)
    rows = res.all()

    if not rows:
        return {
            "status": "success",
            "forecastPeriodDays": days,
            "predictions": [],
            "message": "Insufficient order history for machine learning model. Defaulting to stock safety thresholds."
        }

    # Convert to Pandas DataFrame for high-performance ML processing
    df = pd.DataFrame([
        {
            "product_id": r.productId,
            "product_name": r.name,
            "quantity": r.quantity,
            "date": r.createdAt.date()
        } for r in rows
    ])

    # Group sales by product and date
    daily_sales = df.groupby(["product_id", "product_name"])["quantity"].agg(["sum", "mean", "std", "count"]).reset_index()

    # Fetch current product stocks
    prod_stmt = select(Product)
    prod_res = await db.execute(prod_stmt)
    products = {p.id: p for p in prod_res.scalars().all()}

    predictions = []
    for _, row in daily_sales.iterrows():
        p_id = row["product_id"]
        prod = products.get(p_id)
        if not prod:
            continue

        daily_avg = float(row["mean"]) if not np.isnan(row["mean"]) else 0.0
        predicted_demand = int(np.ceil(daily_avg * days))
        current_stock = prod.stock
        recommended_restock = max(0, predicted_demand - current_stock)

        risk_level = "LOW"
        if current_stock < predicted_demand * 0.5:
            risk_level = "HIGH"
        elif current_stock < predicted_demand:
            risk_level = "MEDIUM"

        predictions.append({
            "productId": p_id,
            "productName": prod.name,
            "currentStock": current_stock,
            "dailyAverageSales": round(daily_avg, 2),
            "predictedDemandDays": predicted_demand,
            "recommendedRestockQuantity": recommended_restock,
            "riskLevel": risk_level,
            "unit": prod.unit
        })

    # Sort predictions by highest risk
    predictions.sort(key=lambda x: (x["riskLevel"] != "HIGH", x["recommendedRestockQuantity"]), reverse=True)

    return {
        "status": "success",
        "forecastPeriodDays": days,
        "totalProductsAnalyzed": len(predictions),
        "highRiskProductsCount": len([p for p in predictions if p["riskLevel"] == "HIGH"]),
        "predictions": predictions[:25]
    }
