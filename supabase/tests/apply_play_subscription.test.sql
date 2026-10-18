-- Test Script for apply_play_subscription Function
-- Run with: psql or supabase test db

BEGIN;

-- 1. Assert exactly ONE overload of apply_play_subscription exists in pg_proc
DO $$
DECLARE
  v_proc_count INT;
BEGIN
  SELECT COUNT(*) INTO v_proc_count
  FROM pg_proc
  WHERE proname = 'apply_play_subscription';

  IF v_proc_count <> 1 THEN
    RAISE EXCEPTION 'Test Failed: Expected 1 apply_play_subscription overload, found %', v_proc_count;
  ELSE
    RAISE NOTICE 'SUCCESS: Exactly 1 apply_play_subscription overload exists in pg_proc.';
  END IF;
END $$;

-- 2. Setup Test Users
INSERT INTO auth.users (id, email)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'user1@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'user2@test.com')
ON CONFLICT (id) DO NOTHING;

-- 3. Test Initial Subscription Apply
SELECT public.apply_play_subscription(
  'token_alpha_123'::text,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'buildera_monthly'::text,
  'order_001'::text,
  'active'::text,
  NOW() + INTERVAL '30 days',
  TRUE,
  'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'::text,
  NULL::text,
  FALSE,
  FALSE,
  '{}'::jsonb,
  100000::numeric
);

-- Verify play_purchases row
SELECT * FROM public.play_purchases WHERE purchase_token = 'token_alpha_123';

-- Verify subscriptions row
SELECT * FROM public.subscriptions WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- 4. Test Idempotency (Repeat call should not duplicate history)
SELECT public.apply_play_subscription(
  'token_alpha_123'::text,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'buildera_monthly'::text,
  'order_001'::text,
  'active'::text,
  NOW() + INTERVAL '30 days',
  TRUE,
  'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'::text,
  NULL::text,
  FALSE,
  FALSE,
  '{}'::jsonb,
  100000::numeric
);

-- Verify history count is exactly 1
SELECT COUNT(*) FROM public.subscription_history WHERE external_id = 'order_001';

-- 5. Test Token Re-assignment Block (P0409)
DO $$
BEGIN
  BEGIN
    PERFORM public.apply_play_subscription(
      'token_alpha_123'::text,
      '22222222-2222-2222-2222-222222222222'::uuid,
      'buildera_monthly'::text,
      'order_002'::text,
      'active'::text,
      NOW() + INTERVAL '30 days',
      TRUE,
      'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'::text
    );
    RAISE EXCEPTION 'Test Failed: P0409 should have been raised!';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE = 'P0409' THEN
      RAISE NOTICE 'SUCCESS: P0409 raised as expected when token is claimed by another user.';
    ELSE
      RAISE EXCEPTION 'Unexpected Exception: %', SQLERRM;
    END IF;
  END;
END $$;

-- 6. Test Pending 'none' status non-overwrite of active subscription
SELECT public.apply_play_subscription(
  'token_pending_456'::text,
  '11111111-1111-1111-1111-111111111111'::uuid,
  'buildera_monthly'::text,
  'order_003'::text,
  'none'::text,
  NOW() + INTERVAL '30 days',
  TRUE,
  'ACKNOWLEDGEMENT_STATE_PENDING'::text
);

-- Verify subscription remains active
SELECT status FROM public.subscriptions WHERE user_id = '11111111-1111-1111-1111-111111111111';

ROLLBACK;
