-- Migration: Create store_admins table and add cashier tracking columns

-- 1. Create store_admins table
CREATE TABLE IF NOT EXISTS public.store_admins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  pin_salt TEXT NOT NULL,
  pin_iterations INTEGER NOT NULL DEFAULT 20000,
  role TEXT NOT NULL DEFAULT 'cashier',
  is_active BOOLEAN NOT NULL DEFAULT true,
  can_edit_price BOOLEAN NOT NULL DEFAULT true,
  can_give_discount BOOLEAN NOT NULL DEFAULT true,
  can_void BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index on user_id
CREATE INDEX IF NOT EXISTS store_admins_user_id_idx ON public.store_admins (user_id);

-- Enable RLS
ALTER TABLE public.store_admins ENABLE ROW LEVEL SECURITY;

-- Row Level Security Policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'store_admins' AND policyname = 'Users can view own store_admins'
  ) THEN
    CREATE POLICY "Users can view own store_admins" ON public.store_admins FOR SELECT TO authenticated USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'store_admins' AND policyname = 'Users can insert own store_admins'
  ) THEN
    CREATE POLICY "Users can insert own store_admins" ON public.store_admins FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'store_admins' AND policyname = 'Users can update own store_admins'
  ) THEN
    CREATE POLICY "Users can update own store_admins" ON public.store_admins FOR UPDATE TO authenticated USING (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'store_admins' AND policyname = 'Users can delete own store_admins'
  ) THEN
    CREATE POLICY "Users can delete own store_admins" ON public.store_admins FOR DELETE TO authenticated USING (auth.uid() = user_id);
  END IF;
END $$;

-- 2. Add cashier tracking columns to transactions and debt_payments if not present
-- Note: Check existing table structure in public schema before running manually
ALTER TABLE public.transactions ADD COLUMN IF NOT EXISTS cashier_id UUID;
ALTER TABLE public.debt_payments ADD COLUMN IF NOT EXISTS cashier_id UUID;
ALTER TABLE public.debt_payments ADD COLUMN IF NOT EXISTS cashier_name TEXT;
