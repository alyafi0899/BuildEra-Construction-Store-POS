# Google Play Billing Subscriptions & Freemium Entitlement System

This document describes the complete architecture, database security rules, Edge Functions, client lifecycle, and manual setup instructions for **BuildEra POS**.

---

## 1. Architecture Overview

```
┌────────────────────────┐      (1) buySubscription      ┌─────────────────────────┐
│                        │─────────────────────────────>│                         │
│  Flutter Client (POS)  │                              │  Google Play Billing    │
│                        │<─────────────────────────────│                         │
└────────────────────────┘      (2) Purchase Details    └─────────────────────────┘
            │                                                        │
            │ (3) verify-play-purchase                               │
            ▼                                                        │
┌────────────────────────┐                                           │
│  verify-play-purchase  │ (4) subscriptionsv2.get                   │
│  (Supabase Edge Func)  │───────────────────────────────────────────┤
└────────────────────────┘                                           │ (5) Real-Time
            │                                                        │     Developer
            │ (6) apply_play_subscription                            │     Notifications
            ▼                                                        ▼
┌────────────────────────┐                              ┌─────────────────────────┐
│  Supabase PostgreSQL   │<─────────────────────────────│        play-rtdn        │
│  (DB + RLS Security)   │    (7) apply_play_sub        │  (Supabase Edge Func)   │
└────────────────────────┘                              └─────────────────────────┘
```

---

## 2. Google Play State & Database Status Mapping

| Play State | Mapped Status | Access | Entitlement Tier |
| :--- | :--- | :--- | :--- |
| `SUBSCRIPTION_STATE_ACTIVE` | `active` | Yes | `EntitlementTier.premium` |
| `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` | `grace` | Yes | `EntitlementTier.premium` |
| `SUBSCRIPTION_STATE_CANCELED` | `canceled` | Yes (until `expiresAt`) | `EntitlementTier.premium` |
| `SUBSCRIPTION_STATE_ON_HOLD` | `on_hold` | No | `EntitlementTier.free` |
| `SUBSCRIPTION_STATE_PAUSED` | `paused` | No | `EntitlementTier.free` |
| `SUBSCRIPTION_STATE_EXPIRED` | `expired` | No | `EntitlementTier.free` |
| `SUBSCRIPTION_STATE_UNSPECIFIED` | `none` | No | `EntitlementTier.free` |

---

## 3. Offline Grace Period (72 Hours) & Trusted Time

- **Strict 72-Hour Limit**: Premium snapshot access requires `last_verified_at` server timestamp. If `(nowUtc - last_verified_at) > 72h`, entitlement drops to `EntitlementTier.free` until re-verified.
- **Trusted Time**: `TrustedTimeHelper.nowUtc()` measures elapsed duration. Forward clock jumps are detected via `Stopwatch` (`maxAllowedClockTamperDrift`).
- **Quota Limit**: Free tier enforces 3 max items per transaction and 10 max transactions per day (Asia/Jakarta day rollover).

---

## 4. Manual Setup Instructions

### 1. Google Play Console & Cloud Platform
1. Create `buildera_monthly` and `buildera_yearly` subscription products in Play Console.
2. Enable **Google Play Android Developer API** in Google Cloud Console.
3. Create a **Service Account** with roles to view financial data and manage orders/subscriptions. Download JSON key.

### 2. Pub/Sub RTDN Setup
1. Create Pub/Sub Topic and Push Subscription pointing to:
   `https://<project-ref>.supabase.co/functions/v1/play-rtdn?token=<PLAY_RTDN_TOKEN>`
2. Grant Publisher role to `google-play-developer-notifications@system.gserviceaccount.com`.

### 3. Supabase Secrets
Execute CLI command:
```bash
supabase secrets set GOOGLE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}' ANDROID_PACKAGE_NAME='com.buildera.pos' PLAY_RTDN_TOKEN='your_rtdn_secret_token' RECONCILE_SECRET='your_reconcile_secret'
```

### 4. Database Migration & Deployment Order
```bash
# 1. Push SQL migrations
supabase db push

# 2. Deploy Edge Functions
supabase functions deploy verify-play-purchase play-rtdn reconcile-play-subscriptions xendit-webhook
```

### 5. Verification SQL Query
Run in SQL Editor to confirm no client write policies exist on subscription tables:
```sql
SELECT policyname, tablename, cmd, roles 
FROM pg_policies 
WHERE tablename IN ('subscriptions', 'subscription_history', 'play_purchases');
```

To set manual admin bypass via SQL:
```sql
UPDATE public.subscriptions SET is_bypassed = TRUE WHERE user_id = 'target-user-uuid';
```
