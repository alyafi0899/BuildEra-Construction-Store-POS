ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_id_fkey;
ALTER TABLE public.users
  ADD CONSTRAINT users_id_fkey
  FOREIGN KEY (id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

ALTER TABLE public.sync_metadata
  DROP CONSTRAINT IF EXISTS sync_metadata_user_id_fkey;
ALTER TABLE public.sync_metadata
  ADD CONSTRAINT sync_metadata_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;

ALTER TABLE public.customer_display
  DROP CONSTRAINT IF EXISTS customer_display_user_id_fkey;
ALTER TABLE public.customer_display
  ADD CONSTRAINT customer_display_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES auth.users(id)
  ON DELETE CASCADE;
