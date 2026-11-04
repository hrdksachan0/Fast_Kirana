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


-- 8. CUSTOMER WALLETS TABLE
ALTER TABLE customer_wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "customer_wallets_select_own" ON customer_wallets;
CREATE POLICY "customer_wallets_select_own"
  ON customer_wallets FOR SELECT
  TO authenticated
  USING (
    (select auth.uid())::text = "userId"
    OR ((auth.jwt() ->> 'role') = 'ADMIN')
  );

-- 9. WALLET TRANSACTIONS TABLE
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_transactions_select_own" ON wallet_transactions;
CREATE POLICY "wallet_transactions_select_own"
  ON wallet_transactions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM customer_wallets cw 
      WHERE cw.id = wallet_transactions."walletId" 
        AND (cw."userId" = (select auth.uid())::text OR ((auth.jwt() ->> 'role') = 'ADMIN'))
    )
  );

-- 10. REFERRALS TABLE
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "referrals_select_own" ON referrals;
CREATE POLICY "referrals_select_own"
  ON referrals FOR SELECT
  TO authenticated
  USING (
    (select auth.uid())::text = "referrerId"
    OR (select auth.uid())::text = "refereeId"
    OR ((auth.jwt() ->> 'role') = 'ADMIN')
  );

-- 11. IDEMPOTENCY RECORDS TABLE
ALTER TABLE idempotency_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "idempotency_records_admin_select" ON idempotency_records;
CREATE POLICY "idempotency_records_admin_select"
  ON idempotency_records FOR SELECT
  TO authenticated
  USING ((auth.jwt() ->> 'role') = 'ADMIN');

-- 12. HUB WAITLIST TABLE
ALTER TABLE hub_waitlist ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "hub_waitlist_admin_all" ON hub_waitlist;
CREATE POLICY "hub_waitlist_admin_all"
  ON hub_waitlist FOR ALL
  TO authenticated
  USING ((auth.jwt() ->> 'role') = 'ADMIN')
  WITH CHECK ((auth.jwt() ->> 'role') = 'ADMIN');

-- 13. KITCHEN KOT QUEUE TABLE
ALTER TABLE kitchen_kot_queue ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow service and staff to manage kitchen_kot_queue" ON kitchen_kot_queue;
DROP POLICY IF EXISTS "kitchen_kot_queue_staff_all" ON kitchen_kot_queue;
CREATE POLICY "kitchen_kot_queue_staff_all"
  ON kitchen_kot_queue FOR ALL
  TO authenticated
  USING (
    ((auth.jwt() ->> 'role') = ANY (ARRAY['ADMIN', 'CHEF', 'RESTAURANT_OWNER', 'PICKER']))
  )
  WITH CHECK (
    ((auth.jwt() ->> 'role') = ANY (ARRAY['ADMIN', 'CHEF', 'RESTAURANT_OWNER', 'PICKER']))
  );

-- 14. SECURE SEARCH PATHS ON FUNCTIONS
ALTER FUNCTION public.products_search_vector_update() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_product_stock_from_hub() SET search_path = public, pg_temp;
