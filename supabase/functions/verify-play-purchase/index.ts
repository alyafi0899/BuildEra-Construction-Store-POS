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
  normalizePlan,
} from "../_shared/play_mapping.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const VALID_PRODUCT_IDS = new Set(["buildera_monthly", "buildera_yearly"]);

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Auth" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const saJson = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON") ?? "";
    const packageName = Deno.env.get("ANDROID_PACKAGE_NAME") ?? "";

    if (!saJson || !packageName) {
      return new Response(
        JSON.stringify({ error: "Server Configuration Error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);

    // Verify JWT and get user from Auth header
    const token = authHeader.replace("Bearer ", "");
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);

    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = userData.user.id;
    const body = await req.json();
    const { purchaseToken, productId } = body;

    if (!purchaseToken || !productId || !VALID_PRODUCT_IDS.has(productId)) {
      return new Response(JSON.stringify({ error: "Invalid product or purchase parameters" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Check existing play_purchases binding in Supabase
    const { data: existingPurchases } = await supabaseAdmin
      .from("play_purchases")
      .select("user_id")
      .eq("purchase_token", purchaseToken)
      .maybeSingle();

    if (existingPurchases && existingPurchases.user_id && existingPurchases.user_id !== userId) {
      return new Response(
        JSON.stringify({ error: "Purchase token bound to another user" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Get Google API OAuth Token
    const accessToken = await getGoogleAccessToken(saJson);

    // 2. Fetch Subscription Info from Google Play API (subscriptionsv2)
    const playSub = await getSubscriptionV2({
      packageName,
      token: purchaseToken,
      accessToken,
    });

    // 3. Validate productId in lineItems
    const lineItem = playSub.lineItems?.[0];
    if (!lineItem || lineItem.productId !== productId) {
      return new Response(JSON.stringify({ error: "Product ID mismatch" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Validate obfuscatedExternalAccountId
    const extId = playSub.externalAccountIdentifiers?.obfuscatedExternalAccountId;
    if (!extId || extId !== userId) {
      return new Response(
        JSON.stringify({ error: "Purchase not bound to current user" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. Extract state, amount, trial, expiry
    const state = playSub.subscriptionState;
    const mappedStatus = mapSubscriptionState(state);
    const expiryTime = lineItem.expiryTime;
    const autoRenewing = lineItem.autoRenewingPlan != null;
    const ackState = playSub.acknowledgementState ?? "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
    const testPurchase = playSub.testPurchase != null;
    const isTrial = detectTrial(playSub);
    const amount = extractAmount(playSub);

    // 6. Apply subscription inside Supabase PostgreSQL transaction function
    const { data: applyResult, error: applyError } = await supabaseAdmin.rpc(
      "apply_play_subscription",
      {
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
      }
    );

    if (applyError) {
      if (applyError.code === "P0409" || applyError.message?.includes("P0409")) {
        return new Response(
          JSON.stringify({ error: "Purchase token bound to another user" }),
          { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      console.error(`Apply RPC Error for user ${userId.substring(0, 8)}...:`, applyError.message);
      return new Response(JSON.stringify({ error: "Failed to persist entitlement" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 7. Get server time for client time anchor
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
    console.error("Verification Exception:", err.message ?? "Unknown error");
    return new Response(
      JSON.stringify({ error: "Verification process error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
