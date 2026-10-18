import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  getGoogleAccessToken,
  getSubscriptionV2,
} from "../_shared/google_play.ts";
import {
  mapSubscriptionState,
  detectTrial,
  extractAmount,
  constantTimeEqual,
} from "../_shared/play_mapping.ts";

const VALID_PRODUCT_IDS = new Set(["buildera_monthly", "buildera_yearly"]);

serve(async (req) => {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token") ?? "";
    const rtdnToken = Deno.env.get("PLAY_RTDN_TOKEN") ?? "";

    if (!rtdnToken || !constantTimeEqual(token, rtdnToken)) {
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
    const productId = lineItem?.productId ?? subNotif.subscriptionId;

    if (!productId || !VALID_PRODUCT_IDS.has(productId)) {
      console.warn("RTDN notice: Unknown or missing product ID in notification");
      return new Response(JSON.stringify({ ok: true, note: "Unknown product ID ignored" }), { status: 200 });
    }

    const expiryTime = lineItem?.expiryTime;
    const autoRenewing = lineItem?.autoRenewingPlan != null;
    const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
    const testPurchase = playSub.testPurchase != null;
    const isTrial = detectTrial(playSub);
    const amount = extractAmount(playSub);

    let userId = playSub.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null;

    // Lookup user_id from play_purchases if not returned directly by Google
    const { data: existing } = await supabaseAdmin
      .from("play_purchases")
      .select("user_id")
      .eq("purchase_token", purchaseToken)
      .maybeSingle();

    if (existing && existing.user_id) {
      // Do not rebind if Google reports a different user ID
      userId = existing.user_id;
    }

    const state = playSub.subscriptionState;
    const mappedStatus = mapSubscriptionState(state);

    const { error: applyError } = await supabaseAdmin.rpc("apply_play_subscription", {
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
      p_amount: amount > 0 ? amount : null,
    });

    if (applyError) {
      if (applyError.code === "P0409" || applyError.message?.includes("P0409")) {
        console.warn("RTDN notice: Token bound to another user (P0409)");
        return new Response(JSON.stringify({ ok: true, note: "Token bound to another user" }), { status: 200 });
      }
      console.error("RTDN RPC Error:", applyError.message);
      // Return 500 so Pub/Sub retries transient database errors
      return new Response(JSON.stringify({ error: "Database apply error" }), { status: 500 });
    }

    return new Response(JSON.stringify({ ok: true, synced: true }), { status: 200 });
  } catch (err: any) {
    console.error("RTDN Error:", err.message ?? "Unknown error");
    return new Response(JSON.stringify({ error: "RTDN handling error" }), { status: 500 });
  }
});
