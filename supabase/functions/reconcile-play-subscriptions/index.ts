import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  acknowledgeSubscription,
  getGoogleAccessToken,
  getSubscriptionV2,
} from "../_shared/google_play.ts";

serve(async (req) => {
  try {
    const authHeader = req.headers.get("x-reconcile-secret");
    const reconcileSecret = Deno.env.get("RECONCILE_SECRET");

    if (!reconcileSecret || authHeader !== reconcileSecret) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "";
    const packageName = Deno.env.get("ANDROID_PACKAGE_NAME") ?? "";
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const accessToken = await getGoogleAccessToken(saJson);

    // Find subscriptions expiring within 48 hours or unverified for > 7 days
    const nowIso = new Date().toISOString();
    const future48h = new Date(Date.now() + 48 * 3600 * 1000).toISOString();

    const { data: targets, error } = await supabaseAdmin
      .from("play_purchases")
      .select("*")
      .or(`expiry_time.lte.${future48h},last_synced_at.lte.${new Date(Date.now() - 7 * 86400 * 1000).toISOString()}`)
      .eq("superseded", false);

    if (error) {
      throw error;
    }

    let processed = 0;
    let acknowledged = 0;

    for (const item of targets ?? []) {
      try {
        const playSub = await getSubscriptionV2({
          packageName,
          token: item.purchase_token,
          accessToken,
        });

        const lineItem = playSub.lineItems?.[0];
        const productId = lineItem?.productId ?? item.product_id;
        const expiryTime = lineItem?.expiryTime;
        const autoRenewing = lineItem?.autoRenewingPlan != null;
        const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
        const testPurchase = playSub.testPurchase != null;

        let isTrial = false;
        if (lineItem?.offerDetails?.offerStage === "FREE_TRIAL") {
          isTrial = true;
        }

        const state = playSub.subscriptionState ?? "SUBSCRIPTION_STATE_UNSPECIFIED";
        let mappedStatus = "none";
        if (state === "SUBSCRIPTION_STATE_ACTIVE") mappedStatus = "active";
        else if (state === "SUBSCRIPTION_STATE_IN_GRACE_PERIOD") mappedStatus = "grace";
        else if (state === "SUBSCRIPTION_STATE_CANCELED") mappedStatus = "canceled";
        else if (state === "SUBSCRIPTION_STATE_ON_HOLD") mappedStatus = "on_hold";
        else if (state === "SUBSCRIPTION_STATE_PAUSED") mappedStatus = "paused";
        else if (state === "SUBSCRIPTION_STATE_EXPIRED") mappedStatus = "expired";

        // Acknowledge backstop: If pending acknowledge > 24 hours, acknowledge from server
        if (
          ackState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
          item.user_id &&
          ["active", "grace"].includes(mappedStatus)
        ) {
          try {
            await acknowledgeSubscription({
              packageName,
              subscriptionId: productId,
              token: item.purchase_token,
              accessToken,
            });
            acknowledged++;
          } catch (ackErr) {
            console.warn("Backstop acknowledge notice:", ackErr);
          }
        }

        await supabaseAdmin.rpc("apply_play_subscription", {
          p_purchase_token: item.purchase_token,
          p_user_id: item.user_id,
          p_product_id: productId,
          p_latest_order_id: playSub.latestOrderId ?? item.latest_order_id,
          p_subscription_state: mappedStatus,
          p_expiry_time: expiryTime,
          p_auto_renewing: autoRenewing,
          p_acknowledgement_state: ackState,
          p_linked_purchase_token: playSub.linkedPurchaseToken ?? null,
          p_test_purchase: testPurchase,
          p_is_trial: isTrial,
          p_raw: playSub,
        });

        processed++;
      } catch (itemErr) {
        console.error(`Reconcile error for token ${item.purchase_token}:`, itemErr);
      }
    }

    return new Response(
      JSON.stringify({ ok: true, processed, acknowledged }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: "Reconcile process failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
