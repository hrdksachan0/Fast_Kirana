# Financial Decimal Migration Plan: Float $\to$ Decimal(10, 2)

## 1. Executive Summary & Rationale
Currently, monetary values (`total`, `subtotal`, `deliveryFee`, `taxes`, `refundAmount`, `cashInHand`, etc.) across `Order`, `OrderItem`, `Product`, `RiderWallet`, and `Payout` tables use IEEE 754 `Float` representations. 

### Why Float is dangerous in production finance:
1. **Binary Representation Drift**: Floating-point math cannot precisely represent fractional decimal powers (e.g., `0.1 + 0.2 = 0.30000000000000004`).
2. **Payment Gateway Discrepancies**: Gateways like Cashfree and Razorpay calculate in integer paise (`₹149.50` $\to$ `14950`). Float rounding can produce off-by-one paise discrepancies during webhook validation.
3. **Ledger Invariants**: Aggregating rider COD collection or vendor payouts over thousands of orders causes cumulative rounding errors.

By transitioning monetary columns to **`NUMERIC(10, 2)` / `@db.Decimal(10, 2)`**, FastKirana guarantees fixed-point precision with exact arithmetic up to ₹99,999,999.99.

---

## 2. Target Schema Specifications

### Prisma Schema (`prisma/schema.prisma`)
```prisma
model Order {
  // ...
  subtotal          Decimal       @db.Decimal(10, 2)
  discount          Decimal       @default(0) @db.Decimal(10, 2)
  deliveryFee       Decimal       @default(0) @db.Decimal(10, 2)
  taxes             Decimal       @default(0) @db.Decimal(10, 2)
  miscFee           Decimal       @default(0) @db.Decimal(10, 2)
  total             Decimal       @db.Decimal(10, 2)
  refundAmount      Decimal       @default(0) @db.Decimal(10, 2)
  // ...
}

model OrderItem {
  // ...
  price             Decimal       @db.Decimal(10, 2)
  costPrice         Decimal       @default(0) @db.Decimal(10, 2)
  refundAmount      Decimal       @default(0) @db.Decimal(10, 2)
  // ...
}

model Product {
  // ...
  mrp               Decimal       @db.Decimal(10, 2)
  price             Decimal       @db.Decimal(10, 2)
  discount          Decimal       @default(0) @db.Decimal(10, 2)
  // ...
}

model RiderWallet {
  // ...
  cashInHand        Decimal       @default(0) @db.Decimal(10, 2)
  cashLimit         Decimal       @default(2000) @db.Decimal(10, 2)
  totalCollected    Decimal       @default(0) @db.Decimal(10, 2)
  totalDeposited    Decimal       @default(0) @db.Decimal(10, 2)
  // ...
}
```

### SQLAlchemy Models (`fastapi-backend/models.py`)
```python
from sqlalchemy import Numeric

class Order(Base):
    # ...
    subtotal: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    discount: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"))
    deliveryFee: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"))
    taxes: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"))
    miscFee: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"))
    refundAmount: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0.00"))
    total: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    # ...
```

---

## 3. SQL Execution Script
The complete transactional PostgreSQL script is staged at:
[`prisma/migrations/20261014_monetary_columns_decimal_migration.sql`](file:///d:/Fastkirana/prisma/migrations/20261014_monetary_columns_decimal_migration.sql)

It safely uses `ROUND("column"::numeric, 2)` to eliminate any fractional micro-cent noise from legacy floats during the column type conversion.

---

## 4. Next.js & React 19 Serialization Guard
> [!IMPORTANT]
> Next.js React Server Components (RSC) and server actions cannot serialize `Prisma.Decimal` instances across the React Flight boundary because `Prisma.Decimal` is a custom class.
>
> When updating Prisma types, ensure queries passed directly to Client Components use `.toNumber()` or a serialization helper:
> ```ts
> export function serializeOrder(order: any) {
>   return {
>     ...order,
>     subtotal: Number(order.subtotal),
>     total: Number(order.total),
>     deliveryFee: Number(order.deliveryFee),
>     discount: Number(order.discount),
>     taxes: Number(order.taxes),
>   }
> }
> ```

---

## 5. Verification Checklist Prior to Production Run
1. [x] Transactional SQL script prepared (`ROUND(val::numeric, 2)`).
2. [ ] Staging database dry run: verify table locks take < 500ms under standard transaction.
3. [ ] FastAPI JSON serialization: verify `fastapi.encoders.jsonable_encoder` encodes `Decimal` as `float` or `str` per API contract.
4. [ ] Cashfree gateway binding verification remains 100% compliant with paise conversion (`int(round(float(order.total) * 100))`).
