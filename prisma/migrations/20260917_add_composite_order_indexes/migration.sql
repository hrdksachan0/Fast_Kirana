-- CreateIndex
CREATE INDEX IF NOT EXISTS "orders_combinedId_status_idx" ON "orders"("combinedId", "status");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "orders_restaurantId_createdAt_idx" ON "orders"("restaurantId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "orders_storeId_status_createdAt_idx" ON "orders"("storeId", "status", "createdAt" DESC);
