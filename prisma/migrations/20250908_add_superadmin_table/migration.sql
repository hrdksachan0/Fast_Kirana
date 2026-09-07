-- ==============================================================================
-- FastKirana — Add SuperAdmin Table
-- ==============================================================================
-- Purpose: Replace hardcoded superadmin phone numbers with a database-backed
--          configurable table. Eliminates code changes for onboarding new
--          superadmins.

CREATE TABLE IF NOT EXISTS public.super_admins (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    phone TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL,
    label TEXT NOT NULL DEFAULT '',
    assigned_restaurant_id TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    granted_by TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed existing known superadmins & restaurant staff
INSERT INTO public.super_admins (id, phone, email, label, assigned_restaurant_id, is_active, granted_by)
VALUES
    (gen_random_uuid()::text, '9170942500', 'superadmin@fastkirana.com', 'Super Admin HQ', NULL, true, NULL),
    (gen_random_uuid()::text, '7054470303', 'admin@fastkirana.com', 'Store Operations Manager', NULL, true, NULL),
    (gen_random_uuid()::text, '8112849854', 'asrestaurant3@gmail.com', 'Restaurant Owner REST-101', 'REST-101', true, NULL),
    (gen_random_uuid()::text, '9250138656', 'restaurant@fastkirana.com', 'Wedson Restaurant Owner REST-102', 'REST-102', true, NULL),
    (gen_random_uuid()::text, '7991488783', 'baludyanhotelrestaurant@gmail.com', 'Bal Udyan Restaurant Owner REST-103', 'REST-103', true, NULL)
ON CONFLICT (phone) DO UPDATE SET
    email = EXCLUDED.email,
    label = EXCLUDED.label,
    assigned_restaurant_id = EXCLUDED.assigned_restaurant_id;

CREATE INDEX IF NOT EXISTS idx_super_admins_phone ON public.super_admins(phone);
CREATE INDEX IF NOT EXISTS idx_super_admins_is_active ON public.super_admins(is_active) WHERE is_active = true;
