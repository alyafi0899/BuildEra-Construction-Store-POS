import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  acknowledgeSubscription,
  getGoogleAccessToken,
  getSubscriptionV2,
  GooglePlayApiError,
  parseServiceAccountInput,
  ServiceAccountConfigError,
  maskToken,
} from "../_shared/google_play.ts";
import {
  mapSubscriptionState,
  detectTrial,
  extractAmount,
  normalizePlan,
  resolveBoundUser,
  getOrderId,
  pickLineItem,
} from "../_shared/play_mapping.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const VALID_PRODUCT_IDS = new Set(["buildera_monthly", "buildera_yearly"]);

export async function handleVerify(
  req: Request,
  deps: {
    supabase?: any;
    google?: {
      getAccessToken?: (saJson: string) => Promise<string>;
      getSubscriptionV2?: (args: { packageName: string; token: string; accessToken: string }) => Promise<any>;
      acknowledge?: (args: { packageName: string; subscriptionId: string; token: string; accessToken: string }) => Promise<boolean>;
    };
    now?: () => Date;
    env?: Record<string, string | undefined>;
  } = {}
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      console.error("[verify-play-purchase] [code: unauthorized] Missing Auth header");
      return new Response(JSON.stringify({ error: "Missing Auth", code: "unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const env = deps.env ?? Deno.env.toObject();
    const supabaseUrl = env.SUPABASE_URL ?? "";
    const supabaseServiceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const saJsonInput = env.GOOGLE_SERVICE_ACCOUNT_JSON_B64 || env.GOOGLE_SERVICE_ACCOUNT_JSON || "";
    const packageName = env.ANDROID_PACKAGE_NAME ?? "";

    if (!saJsonInput || !packageName) {
      console.error("[verify-play-purchase] [code: server_config_missing] Missing Google Service Account JSON or ANDROID_PACKAGE_NAME");
      return new Response(
        JSON.stringify({ error: "Server Configuration Error", code: "server_config_missing" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      parseServiceAccountInput(saJsonInput);
    } catch (saErr: any) {
      const code = saErr?.code ?? "server_config_json";
      console.error(`[verify-play-purchase] [code: ${code}] Invalid service account JSON:`, saErr?.message);
      return new Response(
        JSON.stringify({ error: "Server Configuration Error", code }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = deps.supabase ?? createClient(supabaseUrl, supabaseServiceKey);

    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !userData.user) {
      console.error("[verify-play-purchase] [code: unauthorized] JWT user verification failed");
      return new Response(JSON.stringify({ error: "Unauthorized", code: "unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = userData.user.id;
    const body = await req.json();
    const { purchaseToken, productId } = body;

    if (!purchaseToken || !productId || !VALID_PRODUCT_IDS.has(productId)) {
      console.error(`[verify-play-purchase] [code: bad_request] Invalid purchase parameters. Product: ${productId}, token: ${maskToken(purchaseToken)}`);
      return new Response(JSON.stringify({ error: "Invalid product or purchase parameters", code: "bad_request" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: existingPurchases } = await supabaseAdmin
      .from("play_purchases")
      .select("user_id")
      .eq("purchase_token", purchaseToken)
      .maybeSingle();

    if (existingPurchases && existingPurchases.user_id && existingPurchases.user_id !== userId) {
      console.error(`[verify-play-purchase] [code: bound_other_user] Token ${maskToken(purchaseToken)} already bound to user ${maskToken(existingPurchases.user_id)}, requested by ${maskToken(userId)}`);
      return new Response(
        JSON.stringify({ error: "Purchase token bound to another user", code: "bound_other_user" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const google = deps.google ?? { getAccessToken: getGoogleAccessToken, getSubscriptionV2, acknowledge: acknowledgeSubscription };
    const accessToken = await google.getAccessToken!(saJsonInput);
    const playSub = await google.getSubscriptionV2!({
      packageName,
      token: purchaseToken,
      accessToken,
    });
    playSub.purchaseToken = purchaseToken;

    const matchingLineItem = pickLineItem(playSub, productId);

    if (!matchingLineItem) {
      console.error(`[verify-play-purchase] [code: product_mismatch] Product ID mismatch for product: ${productId}, token: ${maskToken(purchaseToken)}`);
      return new Response(JSON.stringify({ error: "Product ID mismatch", code: "product_mismatch" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const extId = playSub.externalAccountIdentifiers?.obfuscatedExternalAccountId;
    const boundUser = await resolveBoundUser(playSub, userId, supabaseAdmin);

    if (extId) {
      if (extId !== userId) {
        console.error(`[verify-play-purchase] [code: not_bound] extId ${maskToken(extId)} does not match userId ${maskToken(userId)}, token: ${maskToken(purchaseToken)}`);
        return new Response(
          JSON.stringify({ error: "Purchase not bound to current user", code: "not_bound" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    } else if (boundUser.userId && boundUser.userId !== userId) {
      console.error(`[verify-play-purchase] [code: not_bound] boundUser ${maskToken(boundUser.userId)} does not match userId ${maskToken(userId)}, token: ${maskToken(purchaseToken)}`);
      return new Response(
        JSON.stringify({ error: "Purchase not bound to current user", code: "not_bound" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const state = playSub.subscriptionState;
    const mappedStatus = mapSubscriptionState(state);
    let expiryTime = matchingLineItem?.expiryTime;
    if (!expiryTime && ["active", "grace", "canceled"].includes(mappedStatus)) {
      const now = deps.now ? deps.now() : new Date();
      const addDays = productId.includes("yearly") ? 365 : 30;
      expiryTime = new Date(now.getTime() + addDays * 86400 * 1000).toISOString();
    }
    const autoRenewing = matchingLineItem.autoRenewingPlan != null;
    const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
    const testPurchase = playSub.testPurchase != null;
    const isTrial = detectTrial(playSub, productId);
    const amount = extractAmount(playSub, productId);
    const boundUserId = boundUser.userId ?? userId;

    if (state === "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED" && playSub.linkedPurchaseToken) {
      try {
        const linkedSub = await google.getSubscriptionV2!({
          packageName,
          token: playSub.linkedPurchaseToken,
          accessToken,
        });
        const linkedLineItem = pickLineItem(linkedSub, productId) ?? linkedSub.lineItems?.[0];
        const linkedProductId = linkedLineItem?.productId ?? productId;
        const linkedBoundUser = await resolveBoundUser(linkedSub, userId, supabaseAdmin);
        const linkedState = mapSubscriptionState(linkedSub.subscriptionState);
        const linkedRpcArgs = {
          p_purchase_token: playSub.linkedPurchaseToken,
          p_user_id: linkedBoundUser.userId ?? boundUserId,
          p_product_id: linkedProductId,
          p_latest_order_id: getOrderId(linkedSub, linkedProductId),
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
        const { error: linkedApplyError } = await supabaseAdmin.rpc("apply_play_subscription", linkedRpcArgs);
        if (linkedApplyError?.code === "23503" && linkedBoundUser.userId) {
          const { error: retryError } = await supabaseAdmin.rpc("apply_play_subscription", { ...linkedRpcArgs, p_user_id: null });
          if (retryError) {
            throw retryError;
          }
        }

        const pendingRpcArgs = {
          p_purchase_token: purchaseToken,
          p_user_id: boundUserId,
          p_product_id: productId,
          p_latest_order_id: getOrderId(playSub, productId),
          p_subscription_state: "none",
          p_expiry_time: expiryTime,
          p_auto_renewing: autoRenewing,
          p_acknowledgement_state: ackState,
          p_linked_purchase_token: playSub.linkedPurchaseToken ?? null,
          p_test_purchase: testPurchase,
          p_is_trial: isTrial,
          p_raw: playSub,
          p_amount: amount > 0 ? amount : null,
        };
        const { error: pendingApplyError } = await supabaseAdmin.rpc("apply_play_subscription", pendingRpcArgs);
        if (pendingApplyError?.code === "23503") {
          const { error: retryError } = await supabaseAdmin.rpc("apply_play_subscription", { ...pendingRpcArgs, p_user_id: null });
          if (retryError) {
            throw retryError;
          }
        }
        if (linkedApplyError || pendingApplyError) {
          throw linkedApplyError ?? pendingApplyError;
        }
      } catch (recoveryErr) {
        console.warn("Recovery for pending purchase canceled failed:", recoveryErr);
      }
    }

    const rpcArgs = {
      p_purchase_token: purchaseToken,
      p_user_id: boundUserId,
      p_product_id: productId,
      p_latest_order_id: getOrderId(playSub, productId),
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

    let { error: applyError } = await supabaseAdmin.rpc("apply_play_subscription", rpcArgs);
    if (applyError?.code === "23503" && boundUserId) {
      ({ error: applyError } = await supabaseAdmin.rpc("apply_play_subscription", { ...rpcArgs, p_user_id: null }));
    }

    if (applyError) {
      if (applyError.code === "P0409" || applyError.message?.includes("P0409")) {
        console.error(`[verify-play-purchase] [code: bound_other_user] RPC P0409 conflict for token ${maskToken(purchaseToken)}`);
        return new Response(
          JSON.stringify({ error: "Purchase token bound to another user", code: "bound_other_user" }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      console.error(`[verify-play-purchase] [code: db_persist] Apply RPC Error for user ${maskToken(userId)}:`, applyError.message);
      return new Response(JSON.stringify({ error: "Failed to persist entitlement", code: "db_persist" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (
      (boundUser.via?.includes("expiredExternalAccountIdentifiers") ||
        boundUser.via?.includes("expiredPurchaseToken") ||
        boundUser.via?.startsWith("play_purchases:")) &&
      playSub.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING"
    ) {
      try {
        await google.acknowledge!({
          packageName,
          subscriptionId: productId,
          token: purchaseToken,
          accessToken,
        });
      } catch (ackErr) {
        console.warn("Server-side acknowledge after rebind failed:", ackErr);
      }
    }

    const { data: serverTime } = await supabaseAdmin.rpc("get_server_time");

    return new Response(
      JSON.stringify({
        ok: true,
        plan: normalizePlan(productId),
        status: mappedStatus,
        expires_at: expiryTime,
        is_trial: isTrial,
        access: ["active", "grace", "canceled"].includes(mappedStatus),
        ack_state: ackState,
        server_time: serverTime ?? new Date().toISOString(),
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    if (err instanceof ServiceAccountConfigError) {
      console.error(`[verify-play-purchase] [code: ${err.code}] Service account config error: ${err.message}`);
      return new Response(
        JSON.stringify({ error: "Server Configuration Error", code: err.code }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (err instanceof GooglePlayApiError) {
      const status = err.status;
      const reason = err.reason ?? "";
      const sanitized = err.sanitizedBody;

      if (
        reason.includes("purchaseTokenMismatch") ||
        reason.includes("applicationNotFound") ||
        sanitized.includes("purchaseTokenMismatch") ||
        sanitized.includes("applicationNotFound")
      ) {
        console.error(`[verify-play-purchase] [code: google_package_mismatch] [googleStatus: ${status}] Google package or token mismatch: ${reason}`);
        return new Response(
          JSON.stringify({ error: "Purchase verification failed", code: "google_package_mismatch" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (status === 410 || reason.includes("purchaseTokenNoLongerValid") || reason.includes("subscriptionNoLongerAvailable")) {
        console.error(`[verify-play-purchase] [code: google_token_invalid] [googleStatus: ${status}] Google token invalid: ${reason}`);
        return new Response(
          JSON.stringify({ error: "Purchase verification failed", code: "google_token_invalid" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if ([400, 404].includes(status)) {
        console.error(`[verify-play-purchase] [code: bad_request] [googleStatus: ${status}] Google Play API error: ${reason}`);
        return new Response(JSON.stringify({ error: "Purchase verification failed", code: "bad_request" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if ([401, 403].includes(status)) {
        console.error(`[verify-play-purchase] [code: google_auth] [googleStatus: ${status}] Google Play auth error: ${reason}`);
        return new Response(JSON.stringify({ error: "Google Play authorization failed", code: "google_auth" }), {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      if ([409, 429].includes(status) || status >= 500 || !status) {
        console.error(`[verify-play-purchase] [code: google_unavailable] [googleStatus: ${status}] Google Play temporary error: ${reason}`);
        return new Response(JSON.stringify({ error: "Service temporarily unavailable", code: "google_unavailable" }), {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    console.error("[verify-play-purchase] [code: internal] Verification Exception:", err?.message ?? "Unknown error");
    return new Response(
      JSON.stringify({ error: "Verification process error", code: "internal" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}

if (import.meta.main) {
  serve((req) => handleVerify(req));
}
