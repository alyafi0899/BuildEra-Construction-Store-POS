ALTER TABLE subscriptions
  ADD COLUMN IF NOT EXISTS is_bypassed BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_subscriptions_is_bypassed
  ON subscriptions (is_bypassed);
