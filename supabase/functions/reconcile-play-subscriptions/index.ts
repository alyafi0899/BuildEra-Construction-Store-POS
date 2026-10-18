import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  acknowledgeSubscription,
  getGoogleAccessToken,
  getSubscriptionV2,
  GooglePlayApiError,
} from "../_shared/google_play.ts";
import {
  mapSubscriptionState,
  detectTrial,
  extractAmount,
  constantTimeEqual,
  getOrderId,
  resolveBoundUser,
  pickLineItem,
} from "../_shared/play_mapping.ts";

const VALID_PRODUCT_IDS = new Set(["buildera_monthly", "buildera_yearly"]);

export async function handleReconcile(req: Request): Promise<Response> {
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

    const { data: expTargets, error: expTargetsError } = await supabaseAdmin
      .from("play_purchases")
      .select("*")
      .eq("superseded", false)
      .is("dead_reason", null)
      .gte("expiry_time", past3Days)
      .lte("expiry_time", future48h)
      .order("last_synced_at", { ascending: true })
      .limit(100);

    if (expTargetsError) {
      throw new Error(`expTargets query failed: ${expTargetsError.message}`);
    }

    const { data: staleTargets, error: staleTargetsError } = await supabaseAdmin
      .from("play_purchases")
      .select("*")
      .eq("superseded", false)
      .is("dead_reason", null)
      .in("subscription_state", ["active", "grace", "canceled"])
      .lte("last_synced_at", past7Days)
      .order("last_synced_at", { ascending: true })
      .limit(50);

    if (staleTargetsError) {
      throw new Error(`staleTargets query failed: ${staleTargetsError.message}`);
    }

    const { data: pendingTargets, error: pendingTargetsError } = await supabaseAdmin
      .from("play_purchases")
      .select("*")
      .eq("superseded", false)
      .is("dead_reason", null)
      .eq("subscription_state", "none")
      .lte("created_at", past1Hour)
      .order("last_synced_at", { ascending: true })
      .limit(50);

    if (pendingTargetsError) {
      throw new Error(`pendingTargets query failed: ${pendingTargetsError.message}`);
    }

    const targetMap = new Map<string, any>();
    for (const t of [...(expTargets ?? []), ...(staleTargets ?? []), ...(pendingTargets ?? [])]) {
      targetMap.set(t.purchase_token, t);
    }
    const targets = Array.from(targetMap.values()).slice(0, 200);

    let processed = 0;
    let failed = 0;
    let skipped = 0;
    let acknowledged = 0;
    let consecutiveGoogleFailures = 0;
    let lastGoogleFailure: { status?: number; reason?: string } | null = null;

    for (const item of targets) {
      try {
        let playSub: any;
        try {
          playSub = await getSubscriptionV2({
            packageName,
            token: item.purchase_token,
            accessToken,
          });
          consecutiveGoogleFailures = 0;
          lastGoogleFailure = null;
        } catch (err) {
          if (err instanceof GooglePlayApiError) {
            const reason = err.reason ?? "unknown";
            lastGoogleFailure = { status: err.status, reason };

            if (err.status === 410 && (reason === "purchaseTokenNoLongerValid" || reason === "subscriptionNoLongerAvailable")) {
              skipped++;
              consecutiveGoogleFailures = 0;
              await supabaseAdmin
                .from("play_purchases")
                .update({ dead_reason: reason, dead_at: new Date().toISOString(), updated_at: new Date().toISOString() })
                .eq("purchase_token", item.purchase_token);
              console.warn("Reconcile token marked dead:", reason);
              continue;
            }

            if ([400, 404, 401, 403].includes(err.status)) {
              failed++;
              consecutiveGoogleFailures++;
              const detail = reason === "purchaseTokenMismatch" ? " Periksa konfigurasi Google (package name / izin service account)" : "";
              console.error("Reconcile failed Google Play token:", `${reason}${detail}`);
              if (consecutiveGoogleFailures >= 5) {
                return new Response(
                  JSON.stringify({ error: "Periksa konfigurasi Google (package name / izin service account)" }),
                  { status: 500, headers: { "Content-Type": "application/json" } }
                );
              }
              continue;
            }

            if ([409, 429].includes(err.status) || err.status >= 500 || !err.status) {
              failed++;
              consecutiveGoogleFailures++;
              console.error("Reconcile transient Google Play error:", reason);
              continue;
            }
          }
          throw err;
        }

        playSub.purchaseToken = item.purchase_token;
        const lineItem = pickLineItem(playSub, item.product_id) ?? playSub.lineItems?.[0];
        const productId = lineItem?.productId ?? item.product_id;
        const expiryTime = lineItem?.expiryTime ?? item.expiry_time;
        const autoRenewing = lineItem?.autoRenewingPlan != null || item.auto_renewing;
        const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
        const testPurchase = playSub.testPurchase != null || item.test_purchase;
        const isTrial = detectTrial(playSub, productId);
        const amount = extractAmount(playSub, productId) || Number(item.raw?.amount ?? 0) || 0;
        const state = playSub.subscriptionState;
        const mappedStatus = mapSubscriptionState(state);

        if (state === "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED" && playSub.linkedPurchaseToken) {
          try {
            const linkedSub = await getSubscriptionV2({
              packageName,
              token: playSub.linkedPurchaseToken,
              accessToken,
            });
            const linkedLineItem = pickLineItem(linkedSub, productId) ?? linkedSub.lineItems?.[0];
            const linkedProductId = linkedLineItem?.productId ?? productId;
            const linkedBoundUser = await resolveBoundUser(linkedSub, null, supabaseAdmin);
            const linkedState = mapSubscriptionState(linkedSub.subscriptionState);
            const linkedRpcArgs = {
              p_purchase_token: playSub.linkedPurchaseToken,
              p_user_id: linkedBoundUser.userId ?? item.user_id ?? null,
              p_product_id: linkedProductId,
              p_latest_order_id: getOrderId(linkedSub, linkedProductId) ?? item.latest_order_id,
              p_subscription_state: linkedState,
              p_expiry_time: linkedLineItem?.expiryTime ?? expiryTime,
              p_auto_renewing: linkedLineItem?.autoRenewingPlan != null || autoRenewing,
              p_acknowledgement_state: linkedSub.acknowledgementState ?? ackState,
              p_linked_purchase_token: linkedSub.linkedPurchaseToken ?? null,
              p_test_purchase: linkedSub.testPurchase != null || testPurchase,
              p_is_trial: detectTrial(linkedSub, linkedProductId) || isTrial,
              p_raw: linkedSub,
              p_amount: extractAmount(linkedSub, linkedProductId) || amount || null,
            };

            const { error: linkedRpcErr } = await supabaseAdmin.rpc("apply_play_subscription", linkedRpcArgs);
            if (linkedRpcErr?.code === "23503" && linkedBoundUser.userId) {
              const { error: retryError } = await supabaseAdmin.rpc("apply_play_subscription", { ...linkedRpcArgs, p_user_id: null });
              if (retryError) {
                throw retryError;
              }
            }

            const { error: pendingRpcErr } = await supabaseAdmin.rpc("apply_play_subscription", {
              p_purchase_token: item.purchase_token,
              p_user_id: linkedBoundUser.userId ?? item.user_id ?? null,
              p_product_id: productId,
              p_latest_order_id: getOrderId(playSub, productId) ?? item.latest_order_id,
              p_subscription_state: "none",
              p_expiry_time: expiryTime,
              p_auto_renewing: autoRenewing,
              p_acknowledgement_state: ackState,
              p_linked_purchase_token: playSub.linkedPurchaseToken ?? null,
              p_test_purchase: testPurchase,
              p_is_trial: isTrial,
              p_raw: playSub,
              p_amount: amount > 0 ? amount : null,
            });

            if (linkedRpcErr || pendingRpcErr) {
              failed++;
              console.error("Reconcile linked recovery RPC error:", linkedRpcErr?.message ?? pendingRpcErr?.message);
            } else {
              processed++;
            }
            continue;
          } catch (err) {
            console.warn("Reconcile linked-token recovery failed:", err);
          }
        }

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

        const boundUser = await resolveBoundUser(playSub, null, supabaseAdmin);
        const rpcArgs = {
          p_purchase_token: item.purchase_token,
          p_user_id: boundUser.userId ?? item.user_id ?? null,
          p_product_id: productId,
          p_latest_order_id: getOrderId(playSub, productId) ?? item.latest_order_id,
          p_subscription_state: mappedStatus,
          p_expiry_time: expiryTime,
          p_auto_renewing: autoRenewing,
          p_acknowledgement_state: ackState,
          p_linked_purchase_token: playSub.linkedPurchaseToken ?? null,
          p_test_purchase: testPurchase,
          p_is_trial: isTrial,
          p_raw: playSub,
          p_amount: amount > 0 ? amount : null,
        };

        let { error: rpcErr } = await supabaseAdmin.rpc("apply_play_subscription", rpcArgs);
        if (rpcErr?.code === "23503" && boundUser.userId) {
          ({ error: rpcErr } = await supabaseAdmin.rpc("apply_play_subscription", { ...rpcArgs, p_user_id: null }));
        }

        if (rpcErr) {
          if (rpcErr.code === "P0409" || rpcErr.message?.includes("P0409")) {
            skipped++;
          } else {
            failed++;
          }
        } else {
          processed++;
        }

        await new Promise((resolve) => setTimeout(resolve, 50));
      } catch (itemErr) {
        failed++;
        console.error("Reconcile item failed:", itemErr);
      }
    }

    return new Response(
      JSON.stringify({ ok: true, processed, failed, skipped, acknowledged }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("Reconcile process failed:", err);
    return new Response(JSON.stringify({ error: "Reconcile process failed" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
}

if (import.meta.main) {
  serve(handleReconcile);
}
