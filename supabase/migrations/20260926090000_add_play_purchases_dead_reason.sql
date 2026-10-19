ALTER TABLE public.play_purchases
  ADD COLUMN IF NOT EXISTS dead_reason text,
  ADD COLUMN IF NOT EXISTS dead_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_play_purchases_dead
  ON public.play_purchases (dead_reason) WHERE dead_reason IS NOT NULL;
