import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
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

const RATE_LIMIT_SECONDS = 60;

export async function handleSync(
  req: Request,
  deps: {
    supabase?: any;
    google?: {
      getAccessToken?: (saJson: string) => Promise<string>;
      getSubscriptionV2?: (args: { packageName: string; token: string; accessToken: string }) => Promise<any>;
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
      return new Response(
        JSON.stringify({ error: "Missing Auth", code: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const env = deps.env ?? Deno.env.toObject();
    const supabaseUrl = env.SUPABASE_URL ?? "";
    const supabaseServiceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const saJsonInput = env.GOOGLE_SERVICE_ACCOUNT_JSON_B64 || env.GOOGLE_SERVICE_ACCOUNT_JSON || "";
    const packageName = env.ANDROID_PACKAGE_NAME ?? "";

    if (!saJsonInput || !packageName) {
      return new Response(
        JSON.stringify({ error: "Server Configuration Error", code: "server_config_missing" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    try {
      parseServiceAccountInput(saJsonInput);
    } catch (saErr: any) {
      const code = saErr?.code ?? "server_config_json";
      return new Response(
        JSON.stringify({ error: "Server Configuration Error", code }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = deps.supabase ?? createClient(supabaseUrl, supabaseServiceKey);

    const token = authHeader.replace(/^Bearer\s+/i, "");
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !userData.user) {
      return new Response(
        JSON.stringify({ error: "Unauthorized", code: "unauthorized" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userId = userData.user.id;

    // 1. Fetch current subscription for user from subscriptions table
    const { data: currentSub } = await supabaseAdmin
      .from("subscriptions")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    // 2. Fetch latest play_purchases rows for user
    const { data: playRows, error: rowsErr } = await supabaseAdmin
      .from("play_purchases")
      .select("*")
      .eq("user_id", userId)
      .eq("superseded", false)
      .is("dead_reason", null)
      .order("created_at", { ascending: false })
      .limit(3);

    if (rowsErr) {
      return new Response(
        JSON.stringify({ error: "Database query failed", code: "db_persist" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!playRows || playRows.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          plan: currentSub?.plan_type ?? "free",
          status: currentSub?.status ?? "none",
          expires_at: currentSub?.expires_at ?? null,
          play_state: currentSub?.play_state ?? null,
          rate_limited: false,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const now = deps.now ? deps.now() : new Date();
    const latestRow = playRows[0];
    if (latestRow.last_synced_at) {
      const lastSynced = new Date(latestRow.last_synced_at);
      const diffSec = (now.getTime() - lastSynced.getTime()) / 1000;
      if (diffSec < RATE_LIMIT_SECONDS) {
        return new Response(
          JSON.stringify({
            ok: true,
            plan: currentSub?.plan_type ?? normalizePlan(latestRow.product_id),
            status: currentSub?.status ?? latestRow.subscription_state ?? "none",
            expires_at: currentSub?.expires_at ?? latestRow.expiry_time,
            play_state: currentSub?.play_state ?? latestRow.subscription_state,
            rate_limited: true,
          }),
          { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    const google = deps.google ?? { getAccessToken: getGoogleAccessToken, getSubscriptionV2 };
    const accessToken = await google.getAccessToken!(saJsonInput);

    for (const item of playRows) {
      try {
        const playSub = await google.getSubscriptionV2!({
          packageName,
          token: item.purchase_token,
          accessToken,
        });
        playSub.purchaseToken = item.purchase_token;

        const lineItem = pickLineItem(playSub, item.product_id);
        const productId = lineItem?.productId ?? item.product_id;
        const state = playSub.subscriptionState;
        const mappedStatus = mapSubscriptionState(state);
        let expiryTime = lineItem?.expiryTime;
        if (!expiryTime && ["active", "grace", "canceled"].includes(mappedStatus)) {
          const addDays = productId.includes("yearly") ? 365 : 30;
          expiryTime = new Date(now.getTime() + addDays * 86400 * 1000).toISOString();
        }
        const autoRenewing = lineItem?.autoRenewingPlan != null;
        const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
        const testPurchase = playSub.testPurchase != null;
        const isTrial = detectTrial(playSub, productId);
        const amount = extractAmount(playSub, productId);

        const boundUser = await resolveBoundUser(playSub, userId, supabaseAdmin);
        const rpcArgs = {
          p_purchase_token: item.purchase_token,
          p_user_id: boundUser.userId ?? userId,
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

        let { error: applyError } = await supabaseAdmin.rpc("apply_play_subscription", rpcArgs);
        if (applyError?.code === "23503") {
          await supabaseAdmin.rpc("apply_play_subscription", { ...rpcArgs, p_user_id: null });
        }
      } catch (err: any) {
        if (err instanceof GooglePlayApiError && err.status === 410) {
          await supabaseAdmin
            .from("play_purchases")
            .update({
              dead_reason: "purchaseTokenNoLongerValid",
              dead_at: now.toISOString(),
            })
            .eq("purchase_token", item.purchase_token);
        } else {
          console.warn(`[sync-play-subscription] Error syncing token ${maskToken(item.purchase_token)}:`, err?.message ?? err);
        }
      }
    }

    const { data: refreshedSub } = await supabaseAdmin
      .from("subscriptions")
      .select("*")
      .eq("user_id", userId)
      .maybeSingle();

    return new Response(
      JSON.stringify({
        ok: true,
        plan: refreshedSub?.plan_type ?? "free",
        status: refreshedSub?.status ?? "none",
        expires_at: refreshedSub?.expires_at ?? null,
        play_state: refreshedSub?.play_state ?? null,
        rate_limited: false,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    if (err instanceof ServiceAccountConfigError) {
      return new Response(
        JSON.stringify({ error: "Server Configuration Error", code: err.code }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (err instanceof GooglePlayApiError) {
      const status = err.status;
      const reason = err.reason ?? "";

      if (reason.includes("purchaseTokenMismatch") || reason.includes("applicationNotFound")) {
        return new Response(
          JSON.stringify({ error: "Sync failed", code: "google_package_mismatch" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if ([401, 403].includes(status)) {
        return new Response(
          JSON.stringify({ error: "Google Play authorization failed", code: "google_auth" }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if ([409, 429].includes(status) || status >= 500 || !status) {
        return new Response(
          JSON.stringify({ error: "Service temporarily unavailable", code: "google_unavailable" }),
          { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    return new Response(
      JSON.stringify({ error: "Sync process error", code: "internal" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
}

if (import.meta.main) {
  serve((req) => handleSync(req));
}
