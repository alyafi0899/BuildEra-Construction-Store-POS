-- Migration: Fix apply_play_subscription Function & Backfill Xendit Source
-- Timestamp: 20260926070000

-- 1. Backfill legacy subscriptions to source = 'xendit'
UPDATE public.subscriptions
SET source = 'xendit'
WHERE play_purchase_token IS NULL
   OR source IS NULL
   OR source = 'play' AND play_purchase_token IS NULL;

-- 2. Hardened get_server_time function
CREATE OR REPLACE FUNCTION public.get_server_time()
RETURNS TIMESTAMPTZ
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT NOW();
$$;

GRANT EXECUTE ON FUNCTION public.get_server_time() TO authenticated, anon, service_role;

-- 3. Hardened apply_play_subscription function
-- Drop any previous function overload to avoid Postgres 42725 ambiguity errors
DROP FUNCTION IF EXISTS public.apply_play_subscription(text, uuid, text, text, text, timestamptz, boolean, text, text, boolean, boolean, jsonb);
DROP FUNCTION IF EXISTS public.apply_play_subscription(text, uuid, text, text, text, timestamptz, boolean, text, text, boolean, boolean, jsonb, numeric);

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
  p_raw JSONB DEFAULT '{}'::jsonb,
  p_amount NUMERIC DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_plan_type TEXT;
  v_mapped_status TEXT;
  v_current_sub RECORD;
  v_existing_expiry TIMESTAMPTZ;
  v_existing_source TEXT;
  v_bound_user UUID;
  v_effective_user UUID;
  v_amount NUMERIC;
BEGIN
  -- Determine amount
  IF p_amount IS NOT NULL THEN
    v_amount := p_amount;
  ELSE
    v_amount := CASE WHEN p_product_id LIKE '%yearly%' THEN 1000000 ELSE 100000 END;
  END IF;

  -- Map product_id to plan_type
  IF p_product_id LIKE '%yearly%' THEN
    v_plan_type := 'yearly';
  ELSE
    v_plan_type := 'monthly';
  END IF;

  -- Map subscription_state
  v_mapped_status := LOWER(COALESCE(p_subscription_state, 'none'));

  -- Check user binding on existing token in play_purchases
  SELECT user_id INTO v_bound_user
  FROM public.play_purchases
  WHERE purchase_token = p_purchase_token;

  IF v_bound_user IS NOT NULL AND p_user_id IS NOT NULL AND v_bound_user <> p_user_id THEN
    RAISE EXCEPTION 'Purchase token bound to another user' USING ERRCODE = 'P0409';
  END IF;

  v_effective_user := COALESCE(v_bound_user, p_user_id);

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
    v_effective_user,
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
    user_id = COALESCE(public.play_purchases.user_id, EXCLUDED.user_id),
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

  -- If user_id is bound/resolved, check existing subscriptions row before updating
  IF v_effective_user IS NOT NULL THEN
    SELECT * INTO v_current_sub FROM public.subscriptions WHERE user_id = v_effective_user;

    IF v_current_sub.user_id IS NOT NULL THEN
      v_existing_expiry := v_current_sub.expires_at;
      v_existing_source := COALESCE(v_current_sub.source, 'play');

      -- Do not overwrite active subscription with 'none' (PENDING) status
      IF v_mapped_status = 'none' AND v_current_sub.status IN ('active', 'grace', 'canceled') THEN
        RETURN jsonb_build_object(
          'status', 'skipped',
          'reason', 'Pending purchase does not overwrite existing active subscription'
        );
      END IF;

      -- Non-Play (e.g. Xendit) override protection:
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
      v_effective_user,
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
        user_id,
        plan_type,
        amount,
        status,
        payment_method,
        external_id,
        activated_at,
        expires_at
      ) VALUES (
        v_effective_user,
        v_plan_type,
        v_amount,
        v_mapped_status,
        'Google Play',
        p_latest_order_id,
        NOW(),
        p_expiry_time
      )
      ON CONFLICT (external_id) DO NOTHING;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'status', 'success',
    'user_id', v_effective_user,
    'plan_type', v_plan_type,
    'subscription_state', v_mapped_status,
    'expires_at', p_expiry_time
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.apply_play_subscription FROM public, authenticated, anon;
GRANT EXECUTE ON FUNCTION public.apply_play_subscription TO service_role;
