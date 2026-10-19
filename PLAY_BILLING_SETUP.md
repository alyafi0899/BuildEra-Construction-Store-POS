# Google Play subscriptions: setup and operations

This describes the Play billing server components present in this repository. It does not change Android identifiers or configure external Play Console, Google Cloud, Firebase, or Supabase projects.

## Android identifiers in this checkout

The Android Gradle configuration currently declares:

- `applicationId`: `com.solutivostudio.caltax`
- `namespace`: `com.solutivostudio.caltax`
- The manifest launches `.MainActivity`, resolved here to `com.solutivostudio.caltax.MainActivity` in `android/app/src/main/kotlin/com/solutivostudio/caltax/MainActivity.kt`.
- A second source file also declares `com.example.buildera.MainActivity`; it is not the manifest's matching `MainActivity` package for the configured application ID and namespace.

`android/app/google-services.json` currently contains these `package_name` values:

- `com.example.buildera`
- `com.solutivo.buildera`
- `com.solutivostudio.caltax`

The server's `ANDROID_PACKAGE_NAME` **must exactly match the Android app package/application ID registered in Play Console**. The configured application ID in this checkout is `com.solutivostudio.caltax`; do not substitute a Firebase JSON entry or an obsolete package name. No identifier is changed by this guide.

## Existing server flow

- `verify-play-purchase` requires an Authorization bearer token, validates it through Supabase Auth, verifies the purchase with Google Play subscriptionsv2, and persists through the `apply_play_subscription` database RPC.
- On Android, the client starts a Play purchase, sends its purchase token and product ID to `verify-play-purchase`, and calls `completePurchase` only after the server verifies it. A pending Play purchase remains pending; verification retries transient failures.
- `play-rtdn` accepts Pub/Sub messages at `/functions/v1/play-rtdn?token=...`, checks `PLAY_RTDN_TOKEN`, verifies the message's package name when supplied, retrieves subscription details from Google Play, and applies the result through the same RPC. If `PLAY_PUBSUB_SERVICE_ACCOUNT` is configured, the function additionally requires a verified Pub/Sub OIDC bearer token. `PLAY_RTDN_AUDIENCE` overrides the default audience (the function URL origin and path); without the service-account setting, OIDC validation is not enabled.
- `reconcile-play-subscriptions` requires the `x-reconcile-secret` request header to match `RECONCILE_SECRET`. It selects non-superseded purchases with `dead_reason IS NULL` in expiry, stale active/grace/canceled, and older pending groups, then fetches current Google Play state and applies it. Query limits are 100, 50, and 50 respectively; overlapping tokens are deduplicated and at most 200 are processed per invocation.
- Out-of-app re-subscribe is verified against the authenticated user. A matching Google Play `expiredExternalAccountIdentifiers` or previously bound purchase resolves the account; the handler rebinds and acknowledges an eligible pending purchase. A token already bound to another user is rejected.
- The migrations under `supabase/migrations` define the purchase table, `dead_reason` fields, `apply_play_subscription`, and service-role-only database writes. Apply the repository's migrations to the target Supabase project before relying on the functions.

The supported product IDs hard-coded in the three functions are `buildera_monthly` and `buildera_yearly`.

## Supabase function secrets

Set the secrets in the Supabase project that hosts these functions. Use the full Google service-account JSON as the value; never commit it or put real secrets in documentation.

Required by the corresponding function:

| Secret | Used by | Notes |
| --- | --- | --- |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Verify, RTDN, reconcile | Google service-account JSON used to obtain an Android Publisher API access token. |
| `ANDROID_PACKAGE_NAME` | Verify, RTDN, reconcile | Must exactly equal the app package/application ID in Play Console. |
| `PLAY_RTDN_TOKEN` | RTDN | Shared secret included in the Pub/Sub push URL query string. |
| `RECONCILE_SECRET` | Reconcile | Shared secret sent in the `x-reconcile-secret` header. |

The handlers also read `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` when constructing their admin client. These are standard Supabase Edge Function environment values; confirm they are available in the target project.

Optional RTDN OIDC settings:

| Secret | Notes |
| --- | --- |
| `PLAY_PUBSUB_SERVICE_ACCOUNT` | When set, require OIDC bearer tokens with a verified email equal to this value. |
| `PLAY_RTDN_AUDIENCE` | Optional expected OIDC audience; defaults to the RTDN function URL origin and path. |

Example command with placeholders (replace the values locally; do not use these placeholders as credentials):

```sh
supabase secrets set \
  GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}' \
  ANDROID_PACKAGE_NAME='com.solutivostudio.caltax' \
  PLAY_RTDN_TOKEN='<long-random-secret>' \
  RECONCILE_SECRET='<different-long-random-secret>'
```

## Deployment

Push database migrations first, then deploy the Play functions and the existing Xendit webhook:

```sh
supabase db push
supabase functions deploy verify-play-purchase play-rtdn reconcile-play-subscriptions xendit-webhook
```

The repository's handler tests can be run with Deno once its remote import graph is cached. `--cached-only` prevents network access while tests execute:

```sh
deno test --cached-only --allow-env supabase/functions/tests
```

They use injected Google and Supabase dependencies; they do not need live Play, Pub/Sub, or Supabase requests.

## RTDN setup

Configure a Pub/Sub push subscription to POST to:

```text
https://<project-ref>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>
```

The Play RTDN publisher needs permission to publish to the chosen topic. For OIDC validation, configure the push subscription to issue an OIDC token for the service account whose exact email is stored in `PLAY_PUBSUB_SERVICE_ACCOUNT`. If OIDC is not configured on the function, its implementation falls back to query-token validation only.

## Reconciliation operations

Invoke the deployed reconciliation endpoint with an HTTP POST and the configured secret header:

```sh
curl -X POST \
  'https://<project-ref>.supabase.co/functions/v1/reconcile-play-subscriptions' \
  -H 'x-reconcile-secret: <RECONCILE_SECRET>'
```

On success, the JSON response reports `processed`, `failed`, `skipped`, and `acknowledged` counts. The function excludes rows already marked `dead_reason` and superseded rows. A Google 410 with reason `purchaseTokenNoLongerValid` or `subscriptionNoLongerAvailable` marks the purchase dead; `23503` persistence errors are retried with a null user ID. Google `purchaseTokenMismatch` and other 400/401/403/404 errors are not marked dead; five consecutive Google failures stop the invocation when a configuration/token 4xx is encountered. A successful lookup resets the consecutive-failure counter. Google 409/429/5xx/network failures count as transient failures and are not marked dead. The acknowledge backstop only runs for pending acknowledgements older than 24 hours when the stored purchase has a user and the fetched state maps to `active` or `grace`.

The repository does not install a scheduler. As one daily `pg_cron` + `pg_net` example, enable those extensions in Supabase and replace the project URL and secret placeholders locally (do not commit a real secret):

```sql
select cron.schedule(
  'reconcile-play-subscriptions-daily',
  '0 3 * * *',
  $job$
    select net.http_post(
      url := 'https://<project-ref>.supabase.co/functions/v1/reconcile-play-subscriptions',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-reconcile-secret', '<RECONCILE_SECRET>'
      ),
      body := '{}'::jsonb
    );
  $job$
);
```

## Database policy check

To review write policies for the subscription tables after deployment, run:

```sql
SELECT policyname, tablename, cmd, roles
FROM pg_policies
WHERE tablename IN ('subscriptions', 'subscription_history', 'play_purchases');
```

The migrations revoke client INSERT/UPDATE/DELETE privileges and remove client write policies for these tables. Verify the result in the target database rather than assuming it from local files.

After applying migrations, check the overloaded RPC and `dead_*` columns:

```sql
select pg_get_function_identity_arguments(oid)
from pg_proc
where proname = 'apply_play_subscription';
-- Must return exactly one row.

select column_name
from information_schema.columns
where table_name = 'play_purchases'
  and column_name like 'dead_%';
-- Must return exactly two rows.
```

## Release checklist

For subscriptions, use License Testers and an Internal testing release to verify:

- [ ] Buy a new subscription and restore purchases.
- [ ] Verify renewal, cancel, grace, on hold, expiry, refund, and pending payment.
- [ ] Upgrade monthly to yearly and downgrade yearly to monthly.
- [ ] Re-subscribe from the Play Store subscription center without opening the app.
- [ ] Verify a purchase token cannot be claimed by a different store account.
- [ ] Close the app while paying, then reopen it and verify state recovery.
- [ ] Log in, close the app, and open it again to verify the existing subscription state.

Use [the internal Android printer and release checklist](internal/printer-android-checklist.md) for SPP printer validation and Android release checks.
