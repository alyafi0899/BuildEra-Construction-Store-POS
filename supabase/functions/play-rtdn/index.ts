import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { importJWK, jwtVerify } from "https://deno.land/x/jose@v4.14.4/index.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  getGoogleAccessToken,
  getSubscriptionV2,
  GooglePlayApiError,
} from "../_shared/google_play.ts";
import {
  mapSubscriptionState,
  detectTrial,
  extractAmount,
  constantTimeEqual,
  resolveBoundUser,
  getOrderId,
} from "../_shared/play_mapping.ts";

const VALID_PRODUCT_IDS = new Set(["buildera_monthly", "buildera_yearly"]);

async function validatePlayPubSubRequest(req: Request): Promise<boolean> {
  const serviceAccountEmail = Deno.env.get("PLAY_PUBSUB_SERVICE_ACCOUNT") ?? "";
  if (!serviceAccountEmail) {
    console.warn("PLAY_PUBSUB_SERVICE_ACCOUNT not set; falling back to query-token validation only.");
    return true;
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const bearerToken = authHeader.replace(/^Bearer\s+/i, "");
  if (!bearerToken) {
    return false;
  }

  const audience = Deno.env.get("PLAY_RTDN_AUDIENCE") ?? new URL(req.url).origin + new URL(req.url).pathname;
  const jwksUrl = "https://www.googleapis.com/oauth2/v3/certs";
  const jwks = await fetch(jwksUrl).then((res) => res.json());
  const keys = jwks.keys ?? [];
  const key = keys.find((item: any) => item.use === "sig" && item.kid === JSON.parse(atob(bearerToken.split(".")[0])).kid);
  if (!key) {
    return false;
  }

  const imported = await importJWK(key, "RS256");
  const { payload } = await jwtVerify(bearerToken, imported, {
    audience,
    issuer: "https://accounts.google.com",
  });

  const email = payload.email as string | undefined;
  return Boolean(email && email === serviceAccountEmail && payload.email_verified === true);
}

export async function handleRtdn(req: Request): Promise<Response> {
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

    const isVerified = await validatePlayPubSubRequest(req);
    if (!isVerified) {
      return new Response(JSON.stringify({ error: "Pub/Sub OIDC validation failed" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    if (!body.message || !body.message.data) {
      return new Response(JSON.stringify({ ok: true, note: "No message data" }), { status: 200 });
    }

    const decodedStr = atob(body.message.data);
    const notification = JSON.parse(decodedStr);

    const packageName = Deno.env.get("ANDROID_PACKAGE_NAME") ?? "";
    if (notification.packageName && notification.packageName !== packageName) {
      return new Response(JSON.stringify({ ok: true, note: "Package name mismatch ignored" }), { status: 200 });
    }

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

    let playSub;
    try {
      playSub = await getSubscriptionV2({
        packageName,
        token: purchaseToken,
        accessToken,
      });
    } catch (err) {
      if (err instanceof GooglePlayApiError) {
        if ([400, 404, 410].includes(err.status)) {
          console.warn("RTDN ignored Google Play token error:", err.reason ?? err.message);
          return new Response(JSON.stringify({ ok: true, note: "Token no longer valid" }), { status: 200 });
        }
        if ([409, 429].includes(err.status) || err.status >= 500 || !err.status) {
          console.error("RTDN transient Google Play error:", err.reason ?? err.message);
          return new Response(JSON.stringify({ error: "Google Play API temporarily unavailable" }), { status: 500 });
        }
      }
      throw err;
    }

    playSub.purchaseToken = purchaseToken;
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
    const state = playSub.subscriptionState;
    const mappedStatus = mapSubscriptionState(state);
    const boundUser = await resolveBoundUser(playSub, null, supabaseAdmin);

    const { error: applyError } = await supabaseAdmin.rpc("apply_play_subscription", {
      p_purchase_token: purchaseToken,
      p_user_id: boundUser.userId,
      p_product_id: productId,
      p_latest_order_id: getOrderId(playSub),
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
      return new Response(JSON.stringify({ error: "Database apply error" }), { status: 500 });
    }

    return new Response(JSON.stringify({ ok: true, synced: true }), { status: 200 });
  } catch (err: any) {
    console.error("RTDN Error:", err?.message ?? "Unknown error");
    return new Response(JSON.stringify({ error: "RTDN handling error" }), { status: 500 });
  }
}

if (import.meta.main) {
  serve(handleRtdn);
}
