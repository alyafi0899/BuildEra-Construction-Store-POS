-- MASIH PERLU DIVERIFIKASI against the production schema before db push:
-- transactions.id must be UUID. App transaction IDs are UUID v4 strings.
CREATE TABLE IF NOT EXISTS public.transaction_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID NOT NULL
    REFERENCES public.transactions(id) ON DELETE CASCADE,
  product_id UUID NOT NULL,
  product_name TEXT NOT NULL,
  unit_name TEXT NOT NULL,
  conversion_rate NUMERIC NOT NULL,
  quantity NUMERIC NOT NULL,
  cost_price NUMERIC NOT NULL DEFAULT 0,
  original_price NUMERIC NOT NULL,
  sold_price NUMERIC NOT NULL,
  discount_value NUMERIC NOT NULL DEFAULT 0,
  discount_type TEXT NOT NULL DEFAULT 'fixed',
  subtotal NUMERIC NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction_id
  ON public.transaction_items (transaction_id);

ALTER TABLE public.transaction_items ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'transaction_items'
      AND policyname = 'Users can manage own transaction_items'
  ) THEN
    CREATE POLICY "Users can manage own transaction_items"
      ON public.transaction_items
      FOR ALL
      TO authenticated
      USING (user_id = auth.uid())
      WITH CHECK (user_id = auth.uid());
  END IF;
END;
$$;

NOTIFY pgrst, 'reload schema';
