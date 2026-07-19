from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select
from typing import List

from database import get_session
from models import Product, Category, Order

app = FastAPI(title="FastKirana Mobile API", version="1.0.0")

# CORS configuration for local development and mobile emulator access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Welcome to FastKirana FastAPI Server!"}

@app.get("/products", response_model=List[Product])
def get_products(session: Session = Depends(get_session)):
    statement = select(Product).where(Product.isAvailable == True)
    results = session.exec(statement).all()
    return results

@app.get("/products/{product_id}", response_model=Product)
def get_product(product_id: str, session: Session = Depends(get_session)):
    product = session.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product
