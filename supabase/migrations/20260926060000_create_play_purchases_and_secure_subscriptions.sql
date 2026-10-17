-- Migration: Google Play Purchases, Secured Subscriptions, and Server Time Anchor
-- Timestamp: 20260926060000

-- 1. Create Table: play_purchases
CREATE TABLE IF NOT EXISTS public.play_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_token TEXT UNIQUE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id TEXT,
  latest_order_id TEXT,
  subscription_state TEXT,
  expiry_time TIMESTAMPTZ,
  auto_renewing BOOLEAN,
  acknowledgement_state TEXT,
  linked_purchase_token TEXT,
  superseded BOOLEAN DEFAULT FALSE,
  test_purchase BOOLEAN DEFAULT FALSE,
  is_trial BOOLEAN DEFAULT FALSE,
  last_synced_at TIMESTAMPTZ DEFAULT NOW(),
  raw JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Add Play-specific Columns to subscriptions
ALTER TABLE public.subscriptions
  ADD COLUMN IF NOT EXISTS source TEXT NOT NULL DEFAULT 'play',
  ADD COLUMN IF NOT EXISTS play_purchase_token TEXT,
  ADD COLUMN IF NOT EXISTS play_state TEXT,
  ADD COLUMN IF NOT EXISTS auto_renewing BOOLEAN,
  ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_trial BOOLEAN DEFAULT FALSE;

-- 3. Indexes for Fast Lookups
CREATE INDEX IF NOT EXISTS idx_play_purchases_user_id ON public.play_purchases (user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_play_token ON public.subscriptions (play_purchase_token);

-- 4. Enable RLS on play_purchases, subscriptions, subscription_history
ALTER TABLE public.play_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscription_history ENABLE ROW LEVEL SECURITY;

-- RLS SELECT Policies for authenticated users
DROP POLICY IF EXISTS "Users can view own play_purchases" ON public.play_purchases;
CREATE POLICY "Users can view own play_purchases"
ON public.play_purchases FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own subscription" ON public.subscriptions;
CREATE POLICY "Users can view own subscription"
ON public.subscriptions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view own subscription history" ON public.subscription_history;
CREATE POLICY "Users can view own subscription history"
ON public.subscription_history FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- 5. REVOKE Client Write Access (subscriptions & subscription_history)
REVOKE INSERT, UPDATE, DELETE ON public.subscriptions FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.subscription_history FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.play_purchases FROM authenticated, anon;

-- Drop all client write policies safely using a DO loop
DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname, tablename
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename IN ('subscriptions', 'subscription_history', 'play_purchases')
      AND cmd IN ('INSERT', 'UPDATE', 'DELETE', 'ALL')
      AND policyname NOT LIKE '%Service role%'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', pol.policyname, pol.tablename);
  END LOOP;
END $$;

-- 6. SQL Function: get_server_time (Trusted Time Anchor)
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT NOW();
$$;

GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated, anon, service_role;

-- 7. SQL Function: apply_play_subscription (SECURITY DEFINER for service_role)
CREATE OR REPLACE FUNCTION public.apply_play_subscription(
  p_purchase_token TEXT,
  p_user_id UUID,
  p_product_id TEXT,
  p_latest_order_id TEXT,
  p_subscription_state TEXT,
  p_expiry_time TIMESTAMPTZ,
  p_auto_renewing BOOLEAN,
  p_acknowledgement_state TEXT,
  p_linked_purchase_token TEXT DEFAULT NULL,
  p_test_purchase BOOLEAN DEFAULT FALSE,
  p_is_trial BOOLEAN DEFAULT FALSE,
  p_raw JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_plan_type TEXT;
  v_mapped_status TEXT;
  v_current_sub RECORD;
  v_existing_expiry TIMESTAMPTZ;
  v_existing_source TEXT;
BEGIN
  -- Map product_id to plan_type
  IF p_product_id LIKE '%yearly%' THEN
    v_plan_type := 'yearly';
  ELSE
    v_plan_type := 'monthly';
  END IF;

  -- Map subscription_state
  v_mapped_status := LOWER(COALESCE(p_subscription_state, 'none'));

  -- Upsert play_purchases record
  INSERT INTO public.play_purchases (
    purchase_token,
    user_id,
    product_id,
    latest_order_id,
    subscription_state,
    expiry_time,
    auto_renewing,
    acknowledgement_state,
    linked_purchase_token,
    test_purchase,
    is_trial,
    last_synced_at,
    raw,
    updated_at
  ) VALUES (
    p_purchase_token,
    p_user_id,
    p_product_id,
    p_latest_order_id,
    v_mapped_status,
    p_expiry_time,
    p_auto_renewing,
    p_acknowledgement_state,
    p_linked_purchase_token,
    p_test_purchase,
    p_is_trial,
    NOW(),
    p_raw,
    NOW()
  )
  ON CONFLICT (purchase_token) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    product_id = EXCLUDED.product_id,
    latest_order_id = EXCLUDED.latest_order_id,
    subscription_state = EXCLUDED.subscription_state,
    expiry_time = EXCLUDED.expiry_time,
    auto_renewing = EXCLUDED.auto_renewing,
    acknowledgement_state = EXCLUDED.acknowledgement_state,
    linked_purchase_token = EXCLUDED.linked_purchase_token,
    test_purchase = EXCLUDED.test_purchase,
    is_trial = EXCLUDED.is_trial,
    last_synced_at = NOW(),
    raw = EXCLUDED.raw,
    updated_at = NOW();

  -- Handle linked/superseded purchase tokens (upgrades/resubscribes)
  IF p_linked_purchase_token IS NOT NULL AND LENGTH(p_linked_purchase_token) > 0 THEN
    UPDATE public.play_purchases
    SET superseded = TRUE, updated_at = NOW()
    WHERE purchase_token = p_linked_purchase_token;
  END IF;

  -- If user_id is provided, check existing subscriptions row before updating
  IF p_user_id IS NOT NULL THEN
    SELECT * INTO v_current_sub FROM public.subscriptions WHERE user_id = p_user_id;

    IF v_current_sub.user_id IS NOT NULL THEN
      v_existing_expiry := v_current_sub.expires_at;
      v_existing_source := COALESCE(v_current_sub.source, 'play');

      -- Non-Play (e.g. Xendit) override protection:
      -- If existing non-play subscription is active and has a longer expiry, do not overwrite
      IF v_existing_source <> 'play'
         AND v_existing_expiry IS NOT NULL
         AND v_existing_expiry > NOW()
         AND v_existing_expiry > p_expiry_time THEN
        RETURN jsonb_build_object(
          'status', 'skipped',
          'reason', 'Existing non-play subscription has longer active period'
        );
      END IF;

      -- Idempotency check: Do not move expires_at backward unless status transitioned to expired/revoked/on_hold/paused
      IF v_mapped_status IN ('active', 'grace', 'canceled')
         AND v_existing_expiry IS NOT NULL
         AND p_expiry_time < v_existing_expiry THEN
        p_expiry_time := v_existing_expiry;
      END IF;
    END IF;

    -- Upsert public.subscriptions
    INSERT INTO public.subscriptions (
      user_id,
      plan_type,
      status,
      expires_at,
      source,
      play_purchase_token,
      play_state,
      auto_renewing,
      last_verified_at,
      is_trial,
      updated_at
    ) VALUES (
      p_user_id,
      v_plan_type,
      v_mapped_status,
      p_expiry_time,
      'play',
      p_purchase_token,
      v_mapped_status,
      p_auto_renewing,
      NOW(),
      p_is_trial,
      NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
      plan_type = EXCLUDED.plan_type,
      status = EXCLUDED.status,
      expires_at = EXCLUDED.expires_at,
      source = 'play',
      play_purchase_token = EXCLUDED.play_purchase_token,
      play_state = EXCLUDED.play_state,
      auto_renewing = EXCLUDED.auto_renewing,
      last_verified_at = NOW(),
      is_trial = EXCLUDED.is_trial,
      updated_at = NOW();

    -- Record subscription history if latest_order_id exists
    IF p_latest_order_id IS NOT NULL AND LENGTH(p_latest_order_id) > 0 THEN
      INSERT INTO public.subscription_history (
        id,
        user_id,
        plan_type,
        amount,
        payment_method,
        created_at,
        last_external_id
      ) VALUES (
        gen_random_uuid()::text,
        p_user_id,
        v_plan_type,
        CASE WHEN v_plan_type = 'yearly' THEN 1000000 ELSE 100000 END,
        'Google Play',
        NOW(),
        p_latest_order_id
      )
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'user_id', p_user_id,
    'plan_type', v_plan_type,
    'subscription_state', v_mapped_status,
    'expires_at', p_expiry_time
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_play_subscription FROM public, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.apply_play_subscription TO service_role;
