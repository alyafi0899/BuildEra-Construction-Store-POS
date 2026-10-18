-- Test Script for apply_play_subscription Function
-- Run with: psql or supabase test db

BEGIN;

-- 1. Setup Test Users
INSERT INTO auth.users (id, email)
VALUES
  ('11111111-1111-1111-1111-111111111111', 'user1@test.com'),
  ('22222222-2222-2222-2222-222222222222', 'user2@test.com')
ON CONFLICT (id) DO NOTHING;

-- 2. Test Initial Subscription Apply
SELECT public.apply_play_subscription(
  'token_alpha_123',
  '11111111-1111-1111-1111-111111111111'::uuid,
  'buildera_monthly',
  'order_001',
  'active',
  NOW() + INTERVAL '30 days',
  TRUE,
  'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
  NULL,
  FALSE,
  FALSE,
  '{}'::jsonb,
  100000
);

-- Verify play_purchases row
SELECT * FROM public.play_purchases WHERE purchase_token = 'token_alpha_123';

-- Verify subscriptions row
SELECT * FROM public.subscriptions WHERE user_id = '11111111-1111-1111-1111-111111111111';

-- 3. Test Idempotency (Repeat call should not duplicate history)
SELECT public.apply_play_subscription(
  'token_alpha_123',
  '11111111-1111-1111-1111-111111111111'::uuid,
  'buildera_monthly',
  'order_001',
  'active',
  NOW() + INTERVAL '30 days',
  TRUE,
  'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED',
  NULL,
  FALSE,
  FALSE,
  '{}'::jsonb,
  100000
);

-- Verify history count is exactly 1
SELECT COUNT(*) FROM public.subscription_history WHERE last_external_id = 'order_001' OR external_id = 'order_001';

-- 4. Test Token Re-assignment Block (P0409)
DO $$
BEGIN
  BEGIN
    PERFORM public.apply_play_subscription(
      'token_alpha_123',
      '22222222-2222-2222-2222-222222222222'::uuid,
      'buildera_monthly',
      'order_002',
      'active',
      NOW() + INTERVAL '30 days',
      TRUE,
      'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
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

-- 5. Test Pending 'none' status non-overwrite of active subscription
SELECT public.apply_play_subscription(
  'token_pending_456',
  '11111111-1111-1111-1111-111111111111'::uuid,
  'buildera_monthly',
  'order_003',
  'none',
  NOW() + INTERVAL '30 days',
  TRUE,
  'ACKNOWLEDGEMENT_STATE_PENDING'
);

-- Verify subscription remains active
SELECT status FROM public.subscriptions WHERE user_id = '11111111-1111-1111-1111-111111111111';

ROLLBACK;
