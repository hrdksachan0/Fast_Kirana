-- AlterTable: Add cfOrderId to orders if not exists
ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "cfOrderId" TEXT;
CREATE INDEX IF NOT EXISTS "orders_cfOrderId_idx" ON "orders"("cfOrderId");

-- CreateTable: orphan_payments for Cashfree reconciliation and auto-recovery
CREATE TABLE IF NOT EXISTS "orphan_payments" (
    "id" TEXT NOT NULL,
    "cfOrderId" TEXT NOT NULL,
    "cfPaymentId" TEXT,
    "amount" DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    "customerPhone" TEXT,
    "customerName" TEXT,
    "metadata" JSONB,
    "status" TEXT NOT NULL DEFAULT 'UNCLAIMED',
    "orderId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "orphan_payments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "orphan_payments_cfOrderId_key" ON "orphan_payments"("cfOrderId");
CREATE INDEX IF NOT EXISTS "orphan_payments_customerPhone_idx" ON "orphan_payments"("customerPhone");

-- CreateTable: idempotency_records for Redis-independent durable order locking and socket single-use verification
CREATE TABLE IF NOT EXISTS "idempotency_records" (
    "key" TEXT NOT NULL,
    "userId" TEXT,
    "requestHash" TEXT,
    "status" TEXT NOT NULL DEFAULT 'PROCESSING',
    "response" JSONB,
    "orderId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expiresAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "idempotency_records_pkey" PRIMARY KEY ("key")
);

CREATE INDEX IF NOT EXISTS "idempotency_records_userId_idx" ON "idempotency_records"("userId");
CREATE INDEX IF NOT EXISTS "idempotency_records_orderId_idx" ON "idempotency_records"("orderId");
CREATE INDEX IF NOT EXISTS "idempotency_records_expiresAt_idx" ON "idempotency_records"("expiresAt");
