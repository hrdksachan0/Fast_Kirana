-- Add soft delete column to users table
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "deletedAt" TIMESTAMP(3);

-- Create index on deletedAt for filtering
CREATE INDEX IF NOT EXISTS "users_deletedAt_idx" ON "users"("deletedAt");

-- Add index on phone for fast lookups (login, OTP)
CREATE INDEX IF NOT EXISTS "users_phone_idx" ON "users"("phone");

-- Change Order.readableId from Int to String (requires table rebuild in PostgreSQL)
-- Step 1: Add new column as String
ALTER TABLE "orders" ADD COLUMN "readableId_new" VARCHAR(50);

-- Step 2: Copy existing values (convert int to string)
UPDATE "orders" SET "readableId_new" = "readableId"::text WHERE "readableId" IS NOT NULL;

-- Step 3: Drop old constraint
ALTER TABLE "orders" DROP CONSTRAINT IF EXISTS "orders_readableId_key";

-- Step 4: Drop old column
ALTER TABLE "orders" DROP COLUMN "readableId";

-- Step 5: Rename new column
ALTER TABLE "orders" RENAME COLUMN "readableId_new" TO "readableId";

-- Step 6: Re-add unique constraint
ALTER TABLE "orders" ADD CONSTRAINT "orders_readableId_key" UNIQUE ("readableId");

-- Step 7: Re-create index
DROP INDEX IF EXISTS "orders_readableId_idx";
CREATE INDEX "orders_readableId_idx" ON "orders"("readableId");
