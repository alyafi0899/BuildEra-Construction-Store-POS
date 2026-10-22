-- Migration: Create play_billing_health Function for Diagnostics
-- Timestamp: 20261021120000

CREATE OR REPLACE FUNCTION public.play_billing_health()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_has_play_purchases_table BOOLEAN;
  v_overload_count INT;
  v_has_sub_columns BOOLEAN;
  v_has_dead_columns BOOLEAN;
BEGIN
  -- 1. Check play_purchases table existence
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'play_purchases'
  ) INTO v_has_play_purchases_table;

  -- 2. Count apply_play_subscription overloads in pg_proc
  SELECT COUNT(*) INTO v_overload_count
  FROM pg_proc p
  JOIN pg_namespace n ON p.pronamespace = n.oid
  WHERE n.nspname = 'public'
    AND p.proname = 'apply_play_subscription';

  -- 3. Check required columns on subscriptions table
  SELECT (COUNT(*) = 6) INTO v_has_sub_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'subscriptions'
    AND column_name IN (
      'source',
      'play_purchase_token',
      'play_state',
      'auto_renewing',
      'last_verified_at',
      'is_trial'
    );

  -- 4. Check dead_reason and dead_at columns on play_purchases table
  SELECT (COUNT(*) = 2) INTO v_has_dead_columns
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'play_purchases'
    AND column_name IN ('dead_reason', 'dead_at');

  RETURN jsonb_build_object(
    'has_play_purchases_table', COALESCE(v_has_play_purchases_table, false),
    'apply_play_subscription_overload_count', COALESCE(v_overload_count, 0),
    'has_subscription_columns', COALESCE(v_has_sub_columns, false),
    'has_play_purchases_dead_columns', COALESCE(v_has_dead_columns, false)
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.play_billing_health() FROM public, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.play_billing_health() TO service_role;
