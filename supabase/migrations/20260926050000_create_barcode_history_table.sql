-- Safe SQL script for barcode_history table in Supabase
-- Handles existing primary key gracefully, migrates legacy camelCase columns, and ensures all required columns exist

DO $$
BEGIN
  -- 1. Create table if it does not exist at all
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'barcode_history') THEN
    CREATE TABLE public.barcode_history (
      id TEXT NOT NULL PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
      barcode TEXT NOT NULL,
      product_name TEXT NOT NULL DEFAULT '',
      product_id TEXT NOT NULL DEFAULT '',
      used_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      status TEXT NOT NULL DEFAULT 'active',
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );
  ELSE
    -- 2. Add all missing standard columns if table already exists
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS id TEXT;
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS barcode TEXT;
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS product_name TEXT NOT NULL DEFAULT '';
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS product_id TEXT NOT NULL DEFAULT '';
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active';
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
    ALTER TABLE public.barcode_history ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

    -- 3. Migrate and drop legacy camelCase columns if present ("productName", "productId", "usedAt")
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'barcode_history' AND column_name = 'productName'
    ) THEN
      EXECUTE 'UPDATE public.barcode_history SET product_name = "productName" WHERE (product_name IS NULL OR product_name = '''') AND "productName" IS NOT NULL;';
      EXECUTE 'ALTER TABLE public.barcode_history DROP COLUMN IF EXISTS "productName";';
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'barcode_history' AND column_name = 'productId'
    ) THEN
      EXECUTE 'UPDATE public.barcode_history SET product_id = "productId" WHERE (product_id IS NULL OR product_id = '''') AND "productId" IS NOT NULL;';
      EXECUTE 'ALTER TABLE public.barcode_history DROP COLUMN IF EXISTS "productId";';
    END IF;

    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'barcode_history' AND column_name = 'usedAt'
    ) THEN
      EXECUTE 'UPDATE public.barcode_history SET used_at = "usedAt" WHERE "usedAt" IS NOT NULL;';
      EXECUTE 'ALTER TABLE public.barcode_history DROP COLUMN IF EXISTS "usedAt";';
    END IF;

    -- Ensure id is populated for legacy rows before enforcing PRIMARY KEY
    UPDATE public.barcode_history SET id = barcode WHERE (id IS NULL OR id = '') AND barcode IS NOT NULL;
    UPDATE public.barcode_history SET id = gen_random_uuid()::text WHERE id IS NULL OR id = '';
    ALTER TABLE public.barcode_history ALTER COLUMN id SET NOT NULL;

    -- Drop existing primary key constraint if present so we can re-assign to 'id'
    IF EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE table_schema = 'public' AND table_name = 'barcode_history' AND constraint_type = 'PRIMARY KEY'
    ) THEN
      EXECUTE (
        SELECT 'ALTER TABLE public.barcode_history DROP CONSTRAINT ' || quote_ident(constraint_name) || ';'
        FROM information_schema.table_constraints
        WHERE table_schema = 'public' AND table_name = 'barcode_history' AND constraint_type = 'PRIMARY KEY'
        LIMIT 1
      );
    END IF;

    -- Set 'id' as the primary key
    ALTER TABLE public.barcode_history ADD PRIMARY KEY (id);
  END IF;
END $$;

-- 4. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_barcode_history_user_id ON public.barcode_history (user_id);
CREATE INDEX IF NOT EXISTS idx_barcode_history_barcode ON public.barcode_history (barcode);

-- 5. Enable RLS
ALTER TABLE public.barcode_history ENABLE ROW LEVEL SECURITY;

-- 6. RLS Policy for authenticated users
DROP POLICY IF EXISTS "Users can manage own barcode_history" ON public.barcode_history;
CREATE POLICY "Users can manage own barcode_history"
ON public.barcode_history FOR ALL
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- 7. Force PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';
