-- =====================================================================
-- Sync hardening (BuildEra)
-- Idempotent: aman dijalankan ulang.
--  1. Trigger updated_at di server (bukan jam device)
--  2. Tombstone untuk delete lintas device
--  3. sync_metadata: tabel, RLS, realtime
--  4. adjust_stock(): stok berbasis delta + idempotensi
--  5. verify_reset_identity(): lupa password tanpa buka SELECT ke anon
-- =====================================================================

-- 1. Fungsi trigger updated_at ----------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

-- 2. Tombstone ---------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sync_tombstones (
  user_id    uuid        NOT NULL,
  collection text        NOT NULL,
  doc_id     text        NOT NULL,
  deleted_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, collection, doc_id)
);
CREATE INDEX IF NOT EXISTS sync_tombstones_user_deleted_idx
  ON public.sync_tombstones (user_id, deleted_at);

ALTER TABLE public.sync_tombstones ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users read own tombstones" ON public.sync_tombstones;
CREATE POLICY "Users read own tombstones" ON public.sync_tombstones
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.record_tombstone()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.sync_tombstones (user_id, collection, doc_id, deleted_at)
  VALUES (OLD.user_id::text::uuid, TG_TABLE_NAME, OLD.id::text, now())
  ON CONFLICT (user_id, collection, doc_id)
  DO UPDATE SET deleted_at = EXCLUDED.deleted_at;
  RETURN OLD;
END $$;

-- 3. Pasang trigger pada semua tabel yang disinkronkan -----------------
DO $$
DECLARE
  t text;
  all_tables  text[] := ARRAY['products','customers','debts','debt_payments',
    'transactions','purchases','suppliers','shipping_services',
    'restock_history','bill_payments','barcode_history'];
  delta_tables text[] := ARRAY['products','customers','debts','debt_payments',
    'transactions','purchases'];
BEGIN
  FOREACH t IN ARRAY all_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now()', t);
      EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I (user_id, updated_at)', t || '_user_updated_idx', t);
      EXECUTE format('DROP TRIGGER IF EXISTS trg_set_updated_at ON public.%I', t);
      EXECUTE format('CREATE TRIGGER trg_set_updated_at BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t);
    END IF;
  END LOOP;

  FOREACH t IN ARRAY delta_tables LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP TRIGGER IF EXISTS trg_record_tombstone ON public.%I', t);
      EXECUTE format('CREATE TRIGGER trg_record_tombstone AFTER DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.record_tombstone()', t);
    END IF;
  END LOOP;

  IF to_regclass('public.users') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS trg_set_updated_at ON public.users;
    CREATE TRIGGER trg_set_updated_at BEFORE INSERT OR UPDATE ON public.users
      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
  END IF;
END $$;

-- 4. sync_metadata (sinyal realtime antar device) ----------------------
CREATE TABLE IF NOT EXISTS public.sync_metadata (
  user_id            uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  last_update        timestamptz NOT NULL DEFAULT now(),
  updated_by_session text
);
ALTER TABLE public.sync_metadata ADD COLUMN IF NOT EXISTS updated_by_session text;

ALTER TABLE public.sync_metadata ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "sync_metadata select own" ON public.sync_metadata;
CREATE POLICY "sync_metadata select own" ON public.sync_metadata
  FOR SELECT TO authenticated USING (user_id = auth.uid());
DROP POLICY IF EXISTS "sync_metadata insert own" ON public.sync_metadata;
CREATE POLICY "sync_metadata insert own" ON public.sync_metadata
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "sync_metadata update own" ON public.sync_metadata;
CREATE POLICY "sync_metadata update own" ON public.sync_metadata
  FOR UPDATE TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables
                 WHERE pubname = 'supabase_realtime' AND schemaname = 'public'
                   AND tablename = 'sync_metadata') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.sync_metadata;
  END IF;
END $$;

-- 5. Stok berbasis delta (idempoten per op_id) -------------------------
CREATE TABLE IF NOT EXISTS public.sync_applied_ops (
  op_id      text PRIMARY KEY,
  user_id    uuid NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.sync_applied_ops ENABLE ROW LEVEL SECURITY;  -- tanpa policy: hanya via fungsi

CREATE OR REPLACE FUNCTION public.adjust_stock(
  p_product_id text, p_delta numeric, p_op_id text)
RETURNS numeric LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_rows int;
  v_stock numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not authenticated' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.sync_applied_ops (op_id, user_id)
  VALUES (p_op_id, v_uid) ON CONFLICT (op_id) DO NOTHING;
  GET DIAGNOSTICS v_rows = ROW_COUNT;

  IF v_rows = 0 THEN   -- operasi ini sudah pernah diterapkan (retry)
    SELECT stock INTO v_stock FROM public.products
     WHERE id::text = p_product_id AND user_id::text = v_uid::text;
    RETURN v_stock;
  END IF;

  UPDATE public.products
     SET stock = COALESCE(stock, 0) + p_delta
   WHERE id::text = p_product_id AND user_id::text = v_uid::text
   RETURNING stock INTO v_stock;
  RETURN v_stock;
END $$;

REVOKE ALL ON FUNCTION public.adjust_stock(text, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.adjust_stock(text, numeric, text) TO authenticated;

-- 6. Lupa password: cek identitas tanpa membuka SELECT ke anon ---------
CREATE OR REPLACE FUNCTION public.verify_reset_identity(p_email text, p_phone text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.users
     WHERE lower(login_email) = lower(trim(p_email))
       AND phone = trim(p_phone));
$$;
REVOKE ALL ON FUNCTION public.verify_reset_identity(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.verify_reset_identity(text, text) TO anon, authenticated;
