import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  getGoogleAccessToken,
  getSubscriptionV2,
} from "../_shared/google_play.ts";

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token");
    const rtdnToken = Deno.env.get("PLAY_RTDN_TOKEN");

    if (!rtdnToken || token !== rtdnToken) {
      return new Response(JSON.stringify({ error: "Unauthorized token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    if (!body.message || !body.message.data) {
      return new Response(JSON.stringify({ ok: true, note: "No message data" }), { status: 200 });
    }

    // Decode Pub/Sub base64 JSON payload
    const decodedStr = atob(body.message.data);
    const notification = JSON.parse(decodedStr);

    const packageName = Deno.env.get("ANDROID_PACKAGE_NAME") ?? "";
    if (notification.packageName && notification.packageName !== packageName) {
      return new Response(JSON.stringify({ ok: true, note: "Package name mismatch ignored" }), { status: 200 });
    }

    // Test Notifications
    if (notification.testNotification) {
      return new Response(JSON.stringify({ ok: true, note: "Test notification received" }), { status: 200 });
    }

    const subNotif = notification.subscriptionNotification;
    if (!subNotif || !subNotif.purchaseToken) {
      return new Response(JSON.stringify({ ok: true, note: "Non-subscription notification ignored" }), { status: 200 });
    }

    const purchaseToken = subNotif.purchaseToken;
    const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const accessToken = await getGoogleAccessToken(saJson);

    // Fetch fresh subscription details from Google Play
    const playSub = await getSubscriptionV2({
      packageName,
      token: purchaseToken,
      accessToken,
    });

    const lineItem = playSub.lineItems?.[0];
    const productId = lineItem?.productId ?? subNotif.subscriptionId ?? "buildera_monthly";
    const expiryTime = lineItem?.expiryTime;
    const autoRenewing = lineItem?.autoRenewingPlan != null;
    const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
    const testPurchase = playSub.testPurchase != null;

    let isTrial = false;
    if (lineItem?.offerDetails?.offerStage === "FREE_TRIAL") {
      isTrial = true;
    }

    let userId = playSub.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null;

    // Lookup user_id from play_purchases if not returned directly by Google
    if (!userId) {
      const { data: existing } = await supabaseAdmin
        .from("play_purchases")
        .select("user_id")
        .eq("purchase_token", purchaseToken)
        .maybeSingle();

      if (existing) userId = existing.user_id;
    }

    const state = playSub.subscriptionState ?? "SUBSCRIPTION_STATE_UNSPECIFIED";
    let mappedStatus = "none";
    if (state === "SUBSCRIPTION_STATE_ACTIVE") mappedStatus = "active";
    else if (state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD") mappedStatus = "grace";
    else if (state === "SUBSCRIPTION_STATE_CANCELED") mappedStatus = "canceled";
    else if (state === "SUBSCRIPTION_STATE_ON_HOLD") mappedStatus = "on_hold";
    else if (state === "SUBSCRIPTION_STATE_PAUSED") mappedStatus = "paused";
    else if (state === "SUBSCRIPTION_STATE_EXPIRED") mappedStatus = "expired";

    await supabaseAdmin.rpc("apply_play_subscription", {
      p_purchase_token: purchaseToken,
      p_user_id: userId,
      p_product_id: productId,
      p_latest_order_id: playSub.latestOrderId ?? null,
      p_subscription_state: mappedStatus,
      p_expiry_time: expiryTime,
      p_auto_renewing: autoRenewing,
      p_acknowledgement_state: ackState,
      p_linked_purchase_token: playSub.linkedPurchaseToken ?? null,
      p_test_purchase: testPurchase,
      p_is_trial: isTrial,
      p_raw: playSub,
    });

    return new Response(JSON.stringify({ ok: true, synced: true }), { status: 200 });
  } catch (err) {
    // Return 500 so Pub/Sub retries on transient errors
    return new Response(JSON.stringify({ error: "RTDN handling error" }), { status: 500 });
  }
});
