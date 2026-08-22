-- ====================================================================
-- FastKirana - Supabase Postgres Row Level Security (RLS) Policies
-- ====================================================================
-- Run this script in Supabase SQL Editor to enforce strict DB-level access control.
-- Ensures users can ONLY read and write their own data.

-- 1. USERS / PROFILES TABLE
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
  ON users FOR SELECT
  USING (auth.uid()::text = id OR (SELECT role FROM users WHERE id = auth.uid()::text) = 'ADMIN');

CREATE POLICY "Users can update their own profile"
  ON users FOR UPDATE
  USING (auth.uid()::text = id);

-- 2. ORDERS TABLE
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own orders"
  ON orders FOR SELECT
  USING (
    auth.uid()::text = "userId" 
    OR (SELECT role FROM users WHERE id = auth.uid()::text) IN ('ADMIN', 'RESTAURANT_OWNER', 'DELIVERY_PARTNER', 'DRIVER')
  );

CREATE POLICY "Users can insert their own orders"
  ON orders FOR INSERT
  WITH CHECK (auth.uid()::text = "userId");

-- 3. ADDRESSES TABLE
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own addresses"
  ON addresses FOR SELECT
  USING (auth.uid()::text = "userId");

CREATE POLICY "Users can manage their own addresses"
  ON addresses FOR ALL
  USING (auth.uid()::text = "userId");

-- 4. CARTS TABLE
ALTER TABLE carts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own cart"
  ON carts FOR SELECT
  USING (auth.uid()::text = "userId");

CREATE POLICY "Users can modify their own cart"
  ON carts FOR ALL
  USING (auth.uid()::text = "userId");

-- 5. REVIEWS TABLE
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view product reviews"
  ON reviews FOR SELECT
  USING (true);

CREATE POLICY "Users can create/update their own product reviews"
  ON reviews FOR ALL
  USING (auth.uid()::text = "userId");

-- 6. RESTAURANT REVIEWS TABLE
ALTER TABLE "RestaurantReview" ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view restaurant reviews"
  ON "RestaurantReview" FOR SELECT
  USING (true);

CREATE POLICY "Users can create/update their own restaurant reviews"
  ON "RestaurantReview" FOR ALL
  USING (auth.uid()::text = "userId");

-- 7. NOTIFICATIONS TABLE
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (auth.uid()::text = "userId");
