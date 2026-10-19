-- Replace the placeholder UUID with the verified user's auth.users.id.
-- Execute in the Supabase SQL editor with an administrative role.
-- These explicit deletes cover operational tables whose auth.users cascade is
-- not declared in the checked-in migrations. Delete child rows before parents.
DO $$
DECLARE
  target_user_id uuid := '00000000-0000-0000-0000-000000000000';
BEGIN
  DELETE FROM public.debt_payments WHERE user_id = target_user_id;
  DELETE FROM public.bill_payments WHERE user_id = target_user_id;
  DELETE FROM public.transaction_items WHERE user_id = target_user_id;
  DELETE FROM public.purchase_items WHERE user_id = target_user_id;
  DELETE FROM public.product_units WHERE user_id = target_user_id;
  DELETE FROM public.restock_history WHERE user_id = target_user_id;
  DELETE FROM public.transactions WHERE user_id = target_user_id;
  DELETE FROM public.purchases WHERE user_id = target_user_id;
  DELETE FROM public.debts WHERE user_id = target_user_id;
  DELETE FROM public.customers WHERE user_id = target_user_id;
  DELETE FROM public.suppliers WHERE user_id = target_user_id;
  DELETE FROM public.shipping_services WHERE user_id = target_user_id;
  DELETE FROM public.products WHERE user_id = target_user_id;
END $$;

-- Do not delete from storage.objects with SQL: use the Storage API/dashboard
-- to remove bucket "products" objects under users/<target_user_id>/products/.
-- These tables have an explicit ON DELETE CASCADE to auth.users in migrations:
-- users, sync_metadata, customer_display, subscriptions,
-- subscription_history, play_purchases, barcode_history.
-- Delete the auth user separately in Dashboard > Authentication > Users.
