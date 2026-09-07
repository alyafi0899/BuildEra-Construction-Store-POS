-- Drop old policies if they exist to avoid "already exists" errors
DROP POLICY IF EXISTS "Users can view own subscription" ON subscriptions;
DROP POLICY IF EXISTS "Service role can manage all subscriptions" ON subscriptions;
DROP POLICY IF EXISTS "Users can insert own subscription" ON subscriptions;
DROP POLICY IF EXISTS "Users can update own subscription" ON subscriptions;

-- Enable RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own subscription
CREATE POLICY "Users can view own subscription"
ON subscriptions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Restrict Insert/Update to Service Role (Backend only)
-- This prevents users from manually upgrading themselves
CREATE POLICY "Service role can manage all subscriptions"
ON subscriptions FOR ALL
TO service_role
USING (true)
WITH CHECK (true);
