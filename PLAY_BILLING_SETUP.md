# Google Play Billing Integration & Subscription Setup Guide

This document outlines the configuration, product architecture, and trial offer mapping for Google Play Billing Subscriptions in **BuildEra POS**.

---

## 1. Google Play Console Setup

### A. Merchant Account Setup
1. Open [Google Play Console](https://play.google.com/console).
2. Navigate to **Setup -> Payment Profile** and link your Google Merchant Account to enable in-app subscriptions.
3. Upload at least one signed Android App Bundle (AAB) containing the `com.android.vending.BILLING` permission to the **Internal Testing** track.

### B. Product Subscriptions Configuration
Navigate to **Monetize -> Products -> Subscriptions** and create two Subscription Products:

| Product ID | Billing Period | Price | Description |
| :--- | :--- | :--- | :--- |
| `buildera_monthly` | 1 Month | Rp 100.000 | Akses Paket Bulanan Full Features |
| `buildera_yearly` | 1 Year | Rp 1.000.000 | Akses Paket Tahunan Full Features (Hemat 20%) |

---

## 2. Base Plan & Free Trial Offer Mapping

### Free Trial Offers
In Google Play Console, Free Trials are created as **Offers** under the Base Plan (`buildera_monthly` or `buildera_yearly`):

1. Click on Base Plan -> **Add Offer**.
2. Select **Free Trial** as the offer phase (e.g. 7 days or 14 days free trial).
3. Specify the offer eligibility criteria (e.g. New customers only).

### Server & Client Mapping (`subscriptionsv2` API)
When a user subscribes via Google Play Billing:
1. Google Play returns `PurchaseDetails` containing `purchaseToken` and `productID`.
2. The Supabase Edge Function (`create-payment` / `verify-play-purchase`) queries Google Play Developer API:
   `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/subscriptionsv2/tokens/{token}`
3. The server inspects `lineItems[0].offerDetails.offerTags` or `offerPhase`:
   - If in a **Free Trial Phase** (`offerPhase == 'freeTrialPhase'`), the server sets `is_trial = true` and `status = 'active'` in the `subscriptions` table.
   - The Flutter client maps `is_trial` to `Entitlement.premium(isTrial: true)`.
   - The UI displays **"Paket Full Features (Masa Percobaan Trial)"**.

---

## 3. Subscription Status Mapping

| Play Billing Status | Supabase `status` | Client `SubscriptionStatus` | Entitlement Tier |
| :--- | :--- | :--- | :--- |
| `SUBSCRIPTION_STATE_ACTIVE` | `active` | `SubscriptionStatus.active` | `EntitlementTier.premium` |
| `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` | `grace` | `SubscriptionStatus.grace` | `EntitlementTier.premium` |
| `SUBSCRIPTION_STATE_CANCELED` | `canceled` | `SubscriptionStatus.canceled` | `EntitlementTier.premium` (until `expiresAt`) |
| `SUBSCRIPTION_STATE_ON_HOLD` | `on_hold` | `SubscriptionStatus.on_hold` | `EntitlementTier.free` |
| `SUBSCRIPTION_STATE_PAUSED` | `paused` | `SubscriptionStatus.paused` | `EntitlementTier.free` |
| `SUBSCRIPTION_STATE_EXPIRED` | `expired` | `SubscriptionStatus.expired` | `EntitlementTier.free` |

---

## 4. Offline Grace Tolerance (72 Hours)

* When a paid user operates offline in airplane mode, `entitlementProvider` reads the cached `Entitlement` snapshot from local Hive storage.
* If within **72 hours** (`offlineToleranceHours = 72`) of valid premium access, the app maintains full premium access (`EntitlementSource.offlineCache`).
* The cashier is NEVER downgraded to free mode during an active sales day due to network disconnection.
