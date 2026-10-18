import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  acknowledgeSubscription,
  getGoogleAccessToken,
  getSubscriptionV2,
} from "../_shared/google_play.ts";
import {
  mapSubscriptionState,
  detectTrial,
  extractAmount,
  constantTimeEqual,
} from "../_shared/play_mapping.ts";

serve(async (req) => {
  try {
    const authHeader = req.headers.get("x-reconcile-secret") ?? "";
    const reconcileSecret = Deno.env.get("RECONCILE_SECRET") ?? "";

    if (!reconcileSecret || !constantTimeEqual(authHeader, reconcileSecret)) {
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

    const now = new Date();
    const past3Days = new Date(now.getTime() - 3 * 86400 * 1000).toISOString();
    const future48h = new Date(now.getTime() + 48 * 3600 * 1000).toISOString();
    const past7Days = new Date(now.getTime() - 7 * 86400 * 1000).toISOString();
    const past1Hour = new Date(now.getTime() - 3600 * 1000).toISOString();

    // Select target tokens to reconcile
    const { data: targets, error } = await supabaseAdmin
      .from("play_purchases")
      .select("*")
      .eq("superseded", false)
      .or(`expiry_time.gte.${past3Days},expiry_time.lte.${future48h},last_synced_at.lte.${past7Days},created_at.lte.${past1Hour}`)
      .limit(200);

    if (error) {
      throw error;
    }

    let processed = 0;
    let failed = 0;
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
        const isTrial = detectTrial(playSub);
        const amount = extractAmount(playSub);

        const state = playSub.subscriptionState;
        const mappedStatus = mapSubscriptionState(state);

        // Backstop acknowledge: tokens in PENDING acknowledge state > 24 hours ago
        const createdAt = new Date(item.created_at);
        const isOlderThan24h = now.getTime() - createdAt.getTime() > 24 * 3600 * 1000;

        if (
          ackState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
          isOlderThan24h &&
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

        const { error: rpcErr } = await supabaseAdmin.rpc("apply_play_subscription", {
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
          p_amount: amount > 0 ? amount : null,
        });

        if (rpcErr) {
          failed++;
        } else {
          processed++;
        }

        // Small delay between Google API calls to avoid rate limits
        await new Promise((resolve) => setTimeout(resolve, 50));
      } catch (itemErr) {
        failed++;
        console.error(`Reconcile item error:`, itemErr);
      }
    }

    return new Response(
      JSON.stringify({ ok: true, processed, failed, acknowledged }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: "Reconcile process failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
