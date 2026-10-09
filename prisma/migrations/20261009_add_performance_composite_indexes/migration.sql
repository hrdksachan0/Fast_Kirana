-- CreateIndex
CREATE INDEX IF NOT EXISTS "store_inventories_storeId_productId_idx" ON "store_inventories"("storeId", "productId");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "orders_userId_createdAt_idx" ON "orders"("userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "order_items_orderId_productId_idx" ON "order_items"("orderId", "productId");
