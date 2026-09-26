DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  FOR constraint_name IN
    SELECT constraint_row.conname
    FROM pg_constraint AS constraint_row
    WHERE constraint_row.contype = 'f'
      AND constraint_row.conrelid = 'public.subscriptions'::regclass
      AND constraint_row.confrelid = 'auth.users'::regclass
      AND array_length(constraint_row.conkey, 1) = 1
      AND constraint_row.conkey[1] = (
        SELECT attribute_row.attnum
        FROM pg_attribute AS attribute_row
        WHERE attribute_row.attrelid = 'public.subscriptions'::regclass
          AND attribute_row.attname = 'user_id'
          AND NOT attribute_row.attisdropped
      )
  LOOP
    EXECUTE format(
      'ALTER TABLE public.subscriptions DROP CONSTRAINT %I',
      constraint_name
    );
  END LOOP;

  ALTER TABLE public.subscriptions
    ADD CONSTRAINT subscriptions_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES auth.users(id)
    ON DELETE CASCADE;
END $$;
