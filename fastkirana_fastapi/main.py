import uuid
from datetime import datetime
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from sqlmodel import Session, select

from database import get_session
from models import Product, Category, Order, OrderItem, ProductBatch, StockLog, User, Address

app = FastAPI(title="FastKirana Mobile API Hub", version="1.0.0")

# CORS Setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def generate_id():
    return f"py_{uuid.uuid4().hex}"

# --- Request / Response Pydantic Schemas ---

class RegisterRequest(BaseModel):
    name: str
    email: EmailStr
    phone: str
    password: str
    role: Optional[str] = "USER"  # USER, PICKER, DELIVERY

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class AddressCreateRequest(BaseModel):
    userId: str
    label: str  # Home, Work, etc.
    houseNo: str
    street: str
    area: str
    city: str
    pincode: str
    phone: str
    lat: Optional[float] = None
    lng: Optional[float] = None

class CustomerOrderItem(BaseModel):
    productId: str
    quantity: int

class PlaceOrderRequest(BaseModel):
    userId: str
    addressId: str
    items: List[CustomerOrderItem]
    paymentMethod: str  # COD, UPI
    subtotal: float
    discount: float
    deliveryFee: float
    total: float
    notes: Optional[str] = None

class InwardRequest(BaseModel):
    productId: Optional[str] = None
    barcode: Optional[str] = None
    batchCode: str
    quantity: int
    costPrice: float
    expiryDate: str

class POSItem(BaseModel):
    productId: str
    quantity: int
    price: float

class POSCheckoutRequest(BaseModel):
    items: List[POSItem]
    paymentMethod: str
    subtotal: float
    discount: float
    total: float

class UpdateStatusRequest(BaseModel):
    status: str  # CONFIRMED, PACKED, SHIPPED, DELIVERED, CANCELLED
    deliveryUserId: Optional[str] = None
    assignedPickerId: Optional[str] = None

# --- Core APIs ---

@app.get("/")
def read_root():
    return {"message": "Welcome to FastKirana FastAPI Mobile Server!"}


# --- 1. CATEGORIES API ---
@app.get("/api/categories", response_model=List[Category])
def get_categories(session: Session = Depends(get_session)):
    statement = select(Category).order_by(Category.sortOrder.asc())
    return session.exec(statement).all()


# --- 2. PRODUCTS API ---
@app.get("/api/products", response_model=List[Product])
def get_products(categoryId: Optional[str] = None, session: Session = Depends(get_session)):
    if categoryId:
        statement = select(Product).where(
            Product.isAvailable == True,
            Product.categoryId == categoryId
        ).order_by(Product.sortOrder.asc())
    else:
        statement = select(Product).where(Product.isAvailable == True).order_by(Product.sortOrder.asc())
    return session.exec(statement).all()

@app.get("/api/products/{product_id}", response_model=Product)
def get_product(product_id: str, session: Session = Depends(get_session)):
    product = session.get(Product, product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


# --- 3. AUTHENTICATION (REGISTER & LOGIN) ---
@app.post("/api/auth/register")
def register_user(payload: RegisterRequest, session: Session = Depends(get_session)):
    # Check if user already exists
    statement = select(User).where(User.email == payload.email)
    existing_user = session.exec(statement).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    # In production, use bcrypt/argon2 to hash. Mapped to passwordHash.
    new_user = User(
        id=generate_id(),
        name=payload.name,
        email=payload.email,
        phone=payload.phone,
        passwordHash=payload.password, # Plain text for simplicity in dev/testing
        role=payload.role,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    session.add(new_user)
    session.commit()
    session.refresh(new_user)
    return {"success": True, "message": "User registered successfully!", "user": new_user}

@app.post("/api/auth/login")
def login_user(payload: LoginRequest, session: Session = Depends(get_session)):
    statement = select(User).where(User.email == payload.email)
    user = session.exec(statement).first()
    
    if not user or user.passwordHash != payload.password:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Return user details and simulated login token
    return {
        "success": True,
        "token": f"simulated_token_{user.id}",
        "user": {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": user.role
        }
    }


# --- 4. ADDRESS MANAGEMENT ---
@app.post("/api/addresses")
def create_address(payload: AddressCreateRequest, session: Session = Depends(get_session)):
    new_address = Address(
        id=generate_id(),
        userId=payload.userId,
        label=payload.label,
        houseNo=payload.houseNo,
        street=payload.street,
        area=payload.area,
        city=payload.city,
        pincode=payload.pincode,
        phone=payload.phone,
        lat=payload.lat,
        lng=payload.lng,
        isDefault=True
    )
    session.add(new_address)
    session.commit()
    session.refresh(new_address)
    return {"success": True, "address": new_address}

@app.get("/api/addresses/user/{user_id}", response_model=List[Address])
def get_user_addresses(user_id: str, session: Session = Depends(get_session)):
    statement = select(Address).where(Address.userId == user_id)
    return session.exec(statement).all()


# --- 5. CUSTOMER ORDER PLACEMENT (MOBILE) ---
@app.post("/api/orders")
def place_order(payload: PlaceOrderRequest, session: Session = Depends(get_session)):
    try:
        # Get highest order counter
        highest_order_stmt = select(Order).order_by(Order.readableId.desc())
        last_order = session.exec(highest_order_stmt).first()
        next_readable_id = (last_order.readableId or 0) + 1 if last_order else 1

        new_order = Order(
            id=generate_id(),
            readableId=next_readable_id,
            userId=payload.userId,
            addressId=payload.addressId,
            status="PENDING",
            subtotal=payload.subtotal,
            discount=payload.discount,
            deliveryFee=payload.deliveryFee,
            total=payload.total,
            paymentMethod=payload.paymentMethod,
            paymentStatus="PENDING",
            notes=payload.notes,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        session.add(new_order)

        for item in payload.items:
            product = session.get(Product, item.productId)
            if not product:
                raise HTTPException(status_code=404, detail=f"Product {item.productId} not found")

            # Deduct stock (FIFO)
            batches_stmt = select(ProductBatch).where(
                ProductBatch.productId == item.productId,
                ProductBatch.quantity > 0
            ).order_by(ProductBatch.expiryDate.asc())
            batches = session.exec(batches_stmt).all()

            remaining = item.quantity
            for batch in batches:
                if remaining <= 0:
                    break
                deduct = min(batch.quantity, remaining)
                batch.quantity -= deduct
                batch.updatedAt = datetime.utcnow()
                session.add(batch)
                remaining -= deduct

            session.flush()
            active_batches_stmt = select(ProductBatch).where(
                ProductBatch.productId == item.productId,
                ProductBatch.quantity > 0
            ).order_by(ProductBatch.expiryDate.asc())
            active_batches = session.exec(active_batches_stmt).all()

            prev_stock = product.stock
            new_stock = sum(b.quantity for b in active_batches) if active_batches else max(0, prev_stock - item.quantity)
            earliest_expiry = active_batches[0].expiryDate if active_batches else None

            product.stock = new_stock
            product.expiryDate = earliest_expiry
            session.add(product)

            # Write OrderItem
            order_item = OrderItem(
                id=generate_id(),
                orderId=new_order.id,
                productId=item.productId,
                name=product.name,
                price=product.price,
                quantity=item.quantity,
                costPrice=product.costPrice if product.costPrice > 0 else product.price * 0.75
            )
            session.add(order_item)

            # Create StockLog
            stock_log = StockLog(
                id=generate_id(),
                productId=item.productId,
                quantity=-item.quantity,
                type="ONLINE_ORDER",
                prevStock=prev_stock,
                newStock=new_stock,
                createdAt=datetime.utcnow()
            )
            session.add(stock_log)

        session.commit()
        session.refresh(new_order)
        return {"success": True, "orderId": new_order.id, "readableId": new_order.readableId}

    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=str(e))


# --- 6. USER ORDER HISTORY ---
@app.get("/api/orders/user/{user_id}", response_model=List[Order])
def get_user_orders(user_id: str, session: Session = Depends(get_session)):
    statement = select(Order).where(Order.userId == user_id).order_by(Order.createdAt.desc())
    return session.exec(statement).all()


# --- 7. ORDER STATUS UPDATE (FOR PICKERS/RIDERS) ---
@app.patch("/api/orders/{order_id}/status")
def update_order_status(order_id: str, payload: UpdateStatusRequest, session: Session = Depends(get_session)):
    order = session.get(Order, order_id)
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order.status = payload.status
    order.updatedAt = datetime.utcnow()

    if payload.status == "CONFIRMED":
        order.confirmedAt = datetime.utcnow()
    elif payload.status == "PACKED":
        order.packedAt = datetime.utcnow()
    elif payload.status == "SHIPPED":
        order.shippedAt = datetime.utcnow()
    elif payload.status == "DELIVERED":
        order.deliveredAt = datetime.utcnow()
        order.paymentStatus = "PAID"  # Auto mark as paid on delivery

    if payload.deliveryUserId:
        order.deliveryUserId = payload.deliveryUserId
    if payload.assignedPickerId:
        order.assignedPickerId = payload.assignedPickerId

    session.add(order)
    session.commit()
    session.refresh(order)
    return {"success": True, "order": order}


# --- 8. INWARD STOCK ROUTE (POST /api/admin/inward) ---
@app.post("/api/admin/inward")
def inward_batch(payload: InwardRequest, session: Session = Depends(get_session)):
    try:
        if payload.quantity <= 0:
            raise HTTPException(status_code=400, detail="Quantity must be a positive integer")
        if payload.costPrice < 0:
            raise HTTPException(status_code=400, detail="Cost price must be a non-negative number")
        
        try:
            parsed_expiry = datetime.fromisoformat(payload.expiryDate.replace("Z", "+00:00"))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid expiry date format")

        product = None
        if payload.productId:
            product = session.get(Product, payload.productId)
        elif payload.barcode:
            statement = select(Product).where(Product.barcode == payload.barcode.strip())
            product = session.exec(statement).first()

        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        active_product_id = product.id

        new_batch = ProductBatch(
            id=generate_id(),
            productId=active_product_id,
            batchCode=payload.batchCode,
            quantity=payload.quantity,
            initialQty=payload.quantity,
            costPrice=payload.costPrice,
            expiryDate=parsed_expiry,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        session.add(new_batch)

        active_batches_stmt = select(ProductBatch).where(
            ProductBatch.productId == active_product_id,
            ProductBatch.quantity > 0
        ).order_by(ProductBatch.expiryDate.asc())
        active_batches = session.exec(active_batches_stmt).all()

        prev_stock = product.stock
        new_total_stock = sum(b.quantity for b in active_batches)
        if new_batch not in active_batches:
            new_total_stock += new_batch.quantity
            all_batches = sorted(active_batches + [new_batch], key=lambda b: b.expiryDate)
            new_earliest_expiry = all_batches[0].expiryDate if all_batches else None
        else:
            new_earliest_expiry = active_batches[0].expiryDate if active_batches else None

        product.stock = new_total_stock
        product.expiryDate = new_earliest_expiry
        product.costPrice = payload.costPrice
        product.updatedAt = datetime.utcnow()
        session.add(product)

        stock_log = StockLog(
            id=generate_id(),
            productId=active_product_id,
            quantity=payload.quantity,
            type="INWARD_GRN",
            prevStock=prev_stock,
            newStock=new_total_stock,
            createdAt=datetime.utcnow()
        )
        session.add(stock_log)

        session.commit()
        session.refresh(new_batch)
        session.refresh(product)
        
        return {
            "success": True,
            "message": f"Successfully registered batch {payload.batchCode} with {payload.quantity} units.",
            "batch": new_batch,
            "product": product
        }
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=str(e))


# --- 9. RETAIL COUNTER POS CHECKOUT ROUTE (POST /api/admin/inventory/pos-checkout) ---
@app.post("/api/admin/inventory/pos-checkout")
def pos_checkout(payload: POSCheckoutRequest, session: Session = Depends(get_session)):
    try:
        if not payload.items:
            raise HTTPException(status_code=400, detail="No items in transaction")

        walkin_email = "walkin@fastkirana.in"
        user_stmt = select(User).where(User.email == walkin_email)
        walkin_user = session.exec(user_stmt).first()

        if not walkin_user:
            walkin_user = User(
                id=generate_id(),
                email=walkin_email,
                name="Walk-in Customer",
                phone="0000000000",
                role="USER",
                passwordHash="WALKIN_NO_PASS",
                createdAt=datetime.utcnow(),
                updatedAt=datetime.utcnow()
            )
            session.add(walkin_user)
            session.commit()
            session.refresh(walkin_user)

        addr_stmt = select(Address).where(
            Address.userId == walkin_user.id,
            Address.label == "RETAIL_COUNTER"
        )
        walkin_address = session.exec(addr_stmt).first()

        if not walkin_address:
            walkin_address = Address(
                id=generate_id(),
                userId=walkin_user.id,
                label="RETAIL_COUNTER",
                houseNo="Retail Counter",
                street="Ghatampur Store",
                area="Vikas Medical Store, NH34",
                city="Kanpur",
                pincode="209206",
                phone="0000000000",
                isDefault=True
            )
            session.add(walkin_address)
            session.commit()
            session.refresh(walkin_address)

        highest_order_stmt = select(Order).order_by(Order.readableId.desc())
        last_order = session.exec(highest_order_stmt).first()
        next_readable_id = (last_order.readableId or 0) + 1 if last_order else 1

        new_order = Order(
            id=generate_id(),
            readableId=next_readable_id,
            userId=walkin_user.id,
            addressId=walkin_address.id,
            status="DELIVERED",
            subtotal=payload.subtotal,
            discount=payload.discount,
            total=payload.total,
            paymentMethod=payload.paymentMethod,
            paymentStatus="PAID",
            deliveryMethod="RETAIL",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow(),
            confirmedAt=datetime.utcnow(),
            packedAt=datetime.utcnow(),
            shippedAt=datetime.utcnow(),
            deliveredAt=datetime.utcnow()
        )
        session.add(new_order)

        for item in payload.items:
            product = session.get(Product, item.productId)
            if not product:
                raise HTTPException(status_code=404, detail=f"Product with ID {item.productId} not found")

            cost_price = product.costPrice if product.costPrice > 0 else product.price * 0.75

            order_item = OrderItem(
                id=generate_id(),
                orderId=new_order.id,
                productId=item.productId,
                name=product.name,
                price=item.price,
                quantity=item.quantity,
                costPrice=cost_price
            )
            session.add(order_item)

            batches_stmt = select(ProductBatch).where(
                ProductBatch.productId == item.productId,
                ProductBatch.quantity > 0
            ).order_by(ProductBatch.expiryDate.asc())
            batches = session.exec(batches_stmt).all()

            remaining_to_deduct = item.quantity
            for batch in batches:
                if remaining_to_deduct <= 0:
                    break
                deduct = min(batch.quantity, remaining_to_deduct)
                batch.quantity -= deduct
                batch.updatedAt = datetime.utcnow()
                session.add(batch)
                remaining_to_deduct -= deduct

            session.flush()
            active_batches_stmt = select(ProductBatch).where(
                ProductBatch.productId == item.productId,
                ProductBatch.quantity > 0
            ).order_by(ProductBatch.expiryDate.asc())
            active_batches = session.exec(active_batches_stmt).all()

            prev_stock = product.stock
            if active_batches:
                new_total_stock = sum(b.quantity for b in active_batches)
                new_earliest_expiry = active_batches[0].expiryDate
            else:
                new_total_stock = max(0, prev_stock - item.quantity)
                new_earliest_expiry = None

            product.stock = new_total_stock
            product.expiryDate = new_earliest_expiry
            product.updatedAt = datetime.utcnow()
            session.add(product)

            stock_log = StockLog(
                id=generate_id(),
                productId=item.productId,
                quantity=-item.quantity,
                type="RETAIL_POS",
                prevStock=prev_stock,
                newStock=new_total_stock,
                createdAt=datetime.utcnow()
            )
            session.add(stock_log)

        session.commit()
        session.refresh(new_order)
        return {
            "success": True,
            "message": "Retail sale registered successfully!",
            "orderId": new_order.id,
            "readableId": new_order.readableId
        }
    except Exception as e:
        session.rollback()
        raise HTTPException(status_code=500, detail=str(e))
