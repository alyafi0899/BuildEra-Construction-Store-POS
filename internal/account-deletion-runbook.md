# Internal account-deletion runbook

Account deletion is requested by email and processed manually. Do not create or
invoke an Edge Function for account deletion.

## Procedure

1. Verify the request came from the email address registered to the account. If
   it did not, request confirmation from the registered address before taking
   action.
2. Check the user's Google Play subscription. If its status is active, grace,
   canceled, on hold, or paused, tell the user that account deletion does not
   stop Google Play billing and direct them to cancel it in Play Store.
3. Replace the placeholder `target_user_id` in
   `supabase/admin/delete_user_data.sql`, then run that script in the Supabase
   SQL editor. Also delete product images through the Supabase Storage API or
   dashboard from bucket `products`, under the exact prefix
   `users/<target_user_id>/products/`. Do not delete rows from
   `storage.objects` with SQL; use Storage so the underlying objects are
   removed.
4. In Supabase Dashboard, open **Authentication → Users**, locate the verified
   account, and delete it. This cascades to the user-owned rows listed below.
5. Confirm completion to the user by email.
6. Record completion using the minimum operational note necessary (for example,
   date and completed status). Do not copy the user's email, user ID, store
   details, or request contents into the operational log.

The client also keeps per-user Hive data on each device. Cloud deletion cannot
remove an offline cache on a device that is not connected; ask the user to sign
out and clear the app's local data or uninstall the app on their devices.

## Data inventory evidenced by this repository

The application synchronizes these user-owned tables through Supabase:
`products`, `product_units`, `customers`, `debts`, `debt_payments`,
`transactions`, `transaction_items`, `purchases`, `purchase_items`,
`suppliers`, `shipping_services`, `restock_history`, `bill_payments`, and
`barcode_history`. The SQL template explicitly deletes the operational rows
that are not covered by a verified `auth.users` cascade.

The migrations explicitly configure `ON DELETE CASCADE` to `auth.users` for:

- `public.users`, `public.sync_metadata`, and `public.customer_display`
  (`20260926020000_cascade_user_owned_rows.sql`);
- `public.subscriptions` (`20260926010000_cascade_subscription_delete_with_auth_user.sql`);
- `public.subscription_history` (`20260907044758_create_subscription_history_table.sql`);
- `public.play_purchases` (`20260926060000_create_play_purchases_and_secure_subscriptions.sql`);
- `public.barcode_history` (`20260926050000_create_barcode_history_table.sql`).

Product images are uploaded to the `products` Storage bucket at
`users/<user_id>/products/<product_id>.jpg`. The repository does not contain a
Storage bucket deletion policy, so remove those objects explicitly using
Storage API/dashboard before deleting the auth user.

## Google Play compliance note

Google Play's account-deletion requirements call for an easy-to-find deletion
path inside the app, a web resource for deletion requests, and matching
information in the Play Console Data safety form. The current email-based
manual request is a simplified implementation. Review the in-app path, web
resource, and Data safety answers together. If Play review rejects this
approach, the next step is self-service deletion through an authenticated
Edge Function protected by the user's JWT.
