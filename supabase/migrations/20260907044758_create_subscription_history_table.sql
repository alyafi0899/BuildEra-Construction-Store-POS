-- Create subscription_history table
CREATE TABLE IF NOT EXISTS subscription_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    plan_type TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    status TEXT NOT NULL,
    payment_method TEXT,
    external_id TEXT UNIQUE,
    activated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS
ALTER TABLE subscription_history ENABLE ROW LEVEL SECURITY;

-- Policy for users to view their own history (Using DROP IF EXISTS for idempotency)
DROP POLICY IF EXISTS "Users can view own subscription history" ON subscription_history;
CREATE POLICY "Users can view own subscription history"
ON subscription_history FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Policy for service role to manage everything
DROP POLICY IF EXISTS "Service role can manage history" ON subscription_history;
CREATE POLICY "Service role can manage history"
ON subscription_history FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Ensure subscriptions table has necessary columns for grace period and pro-rata
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS grace_period_ends_at TIMESTAMPTZ;
ALTER TABLE subscriptions ADD COLUMN IF NOT EXISTS trial_started_at TIMESTAMPTZ;
