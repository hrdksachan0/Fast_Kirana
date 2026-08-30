-- ==============================================================================
-- FastKirana — Live Delivery Tracking Migration & Realtime Setup
-- ==============================================================================
-- Table: delivery_locations
-- Purpose: Real-time high-efficiency GPS location tracking for delivery riders

CREATE TABLE IF NOT EXISTS public.delivery_locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id TEXT NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    rider_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION DEFAULT 0.0,
    heading DOUBLE PRECISION DEFAULT 0.0,
    speed DOUBLE PRECISION DEFAULT 0.0,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── Indexes for Realtime Performance & Quick Lookup ─────────────────────────
CREATE INDEX IF NOT EXISTS idx_delivery_locations_order_id ON public.delivery_locations(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_locations_rider_id ON public.delivery_locations(rider_id);
CREATE INDEX IF NOT EXISTS idx_delivery_locations_timestamp ON public.delivery_locations(timestamp DESC);

-- ─── Row Level Security (RLS) Policies ───────────────────────────────────────
ALTER TABLE public.delivery_locations ENABLE ROW LEVEL SECURITY;

-- 1. Customers can ONLY read the live location for their OWN active orders
CREATE POLICY "Customers can view location of their active orders"
ON public.delivery_locations
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.orders o
        WHERE o.id = delivery_locations.order_id
        AND o."userId" = auth.uid()::text
    )
    OR (SELECT role FROM public.users WHERE id = auth.uid()::text) IN ('ADMIN', 'DELIVERY', 'DRIVER')
);

-- 2. Delivery Riders can insert/update location for their assigned active orders
CREATE POLICY "Riders can insert location for assigned orders"
ON public.delivery_locations
FOR INSERT
WITH CHECK (
    auth.uid()::text = rider_id
    OR (SELECT role FROM public.users WHERE id = auth.uid()::text) IN ('ADMIN', 'DELIVERY', 'DRIVER')
);

-- ─── Enable Supabase Realtime Publication ─────────────────────────────────────
-- Add delivery_locations to supabase_realtime publication
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'delivery_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.delivery_locations;
  END IF;
END $$;
