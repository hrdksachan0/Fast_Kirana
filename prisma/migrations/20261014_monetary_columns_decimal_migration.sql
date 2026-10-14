-- ========================================================================
-- FastKirana Financial Precision Migration: Float -> NUMERIC(10, 2)
-- Purpose: Eliminate floating point rounding drift across orders, payments,
--          coupons, wallets, vendor payouts, and financial ledgers.
-- ========================================================================

BEGIN;

-- 1. Orders table
ALTER TABLE "orders"
  ALTER COLUMN "subtotal" TYPE NUMERIC(10, 2) USING ROUND("subtotal"::numeric, 2),
  ALTER COLUMN "discount" TYPE NUMERIC(10, 2) USING ROUND("discount"::numeric, 2),
  ALTER COLUMN "deliveryFee" TYPE NUMERIC(10, 2) USING ROUND("deliveryFee"::numeric, 2),
  ALTER COLUMN "taxes" TYPE NUMERIC(10, 2) USING ROUND("taxes"::numeric, 2),
  ALTER COLUMN "miscFee" TYPE NUMERIC(10, 2) USING ROUND("miscFee"::numeric, 2),
  ALTER COLUMN "total" TYPE NUMERIC(10, 2) USING ROUND("total"::numeric, 2),
  ALTER COLUMN "refundAmount" TYPE NUMERIC(10, 2) USING ROUND("refundAmount"::numeric, 2);

-- 2. Order Items table
ALTER TABLE "order_items"
  ALTER COLUMN "price" TYPE NUMERIC(10, 2) USING ROUND("price"::numeric, 2),
  ALTER COLUMN "costPrice" TYPE NUMERIC(10, 2) USING ROUND("costPrice"::numeric, 2),
  ALTER COLUMN "refundAmount" TYPE NUMERIC(10, 2) USING ROUND("refundAmount"::numeric, 2);

-- 3. Products table
ALTER TABLE "products"
  ALTER COLUMN "mrp" TYPE NUMERIC(10, 2) USING ROUND("mrp"::numeric, 2),
  ALTER COLUMN "price" TYPE NUMERIC(10, 2) USING ROUND("price"::numeric, 2),
  ALTER COLUMN "discount" TYPE NUMERIC(10, 2) USING ROUND("discount"::numeric, 2);

-- 4. Product Batches table
ALTER TABLE "product_batches"
  ALTER COLUMN "costPrice" TYPE NUMERIC(10, 2) USING ROUND("costPrice"::numeric, 2);

-- 5. Rider Wallets table
ALTER TABLE "rider_wallets"
  ALTER COLUMN "cashInHand" TYPE NUMERIC(10, 2) USING ROUND("cashInHand"::numeric, 2),
  ALTER COLUMN "cashLimit" TYPE NUMERIC(10, 2) USING ROUND("cashLimit"::numeric, 2),
  ALTER COLUMN "totalCollected" TYPE NUMERIC(10, 2) USING ROUND("totalCollected"::numeric, 2),
  ALTER COLUMN "totalDeposited" TYPE NUMERIC(10, 2) USING ROUND("totalDeposited"::numeric, 2);

-- 6. Cash Deposit Transactions table
ALTER TABLE "cash_deposit_transactions"
  ALTER COLUMN "amount" TYPE NUMERIC(10, 2) USING ROUND("amount"::numeric, 2);

-- 7. Vendor Payouts table
ALTER TABLE "vendor_payouts"
  ALTER COLUMN "amount" TYPE NUMERIC(10, 2) USING ROUND("amount"::numeric, 2);

-- 8. Restaurant Payouts table
ALTER TABLE "restaurant_payouts"
  ALTER COLUMN "amount" TYPE NUMERIC(10, 2) USING ROUND("amount"::numeric, 2);

-- 9. Coupons table (minOrder, value, maxDiscount)
ALTER TABLE "coupons"
  ALTER COLUMN "value" TYPE NUMERIC(10, 2) USING ROUND("value"::numeric, 2),
  ALTER COLUMN "minOrder" TYPE NUMERIC(10, 2) USING ROUND("minOrder"::numeric, 2);

ALTER TABLE "coupons"
  ALTER COLUMN "maxDiscount" TYPE NUMERIC(10, 2) USING CASE WHEN "maxDiscount" IS NOT NULL THEN ROUND("maxDiscount"::numeric, 2) ELSE NULL END;

-- 10. Dark Stores Surge Charge
ALTER TABLE "dark_stores"
  ALTER COLUMN "surgeCharge" TYPE NUMERIC(10, 2) USING ROUND("surgeCharge"::numeric, 2);

COMMIT;
