-- 1. Tambah kolom Store Settings jika belum ada (Safe & Idempotent)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS business_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS owner_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS phone TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS email TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS login_email TEXT,
  ADD COLUMN IF NOT EXISTS address TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS description TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS bank_accounts JSONB NOT NULL DEFAULT '[]'::JSONB,
  ADD COLUMN IF NOT EXISTS security_pin TEXT,
  ADD COLUMN IF NOT EXISTS lock_analytics_page BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS lock_products_page BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS lock_inventory_page BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS receipt_width NUMERIC NOT NULL DEFAULT 80,
  ADD COLUMN IF NOT EXISTS receipt_margin NUMERIC NOT NULL DEFAULT 4,
  ADD COLUMN IF NOT EXISTS use_fast_print BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS printer_transport TEXT NOT NULL DEFAULT 'pdf',
  ADD COLUMN IF NOT EXISTS invoice_design TEXT NOT NULL DEFAULT 'classic',
  ADD COLUMN IF NOT EXISTS print_method TEXT NOT NULL DEFAULT 'pdf',
  ADD COLUMN IF NOT EXISTS invoice_printer_url TEXT,
  ADD COLUMN IF NOT EXISTS label_printer_url TEXT,
  ADD COLUMN IF NOT EXISTS enable_cashier BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_products BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_purchase BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_transactions BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_debts BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_bills BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_barcode BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS enable_analytics BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- 2. Aktifkan Realtime Publication untuk tabel users (Pengecekan Idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'users'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
  END IF;
END $$;

-- 3. Kebijakan Row Level Security (RLS) untuk tabel users
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own record" ON public.users;
CREATE POLICY "Users can view own record" ON public.users
  FOR SELECT TO authenticated USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own record" ON public.users;
CREATE POLICY "Users can update own record" ON public.users
  FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own record" ON public.users;
CREATE POLICY "Users can insert own record" ON public.users
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
