import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  createRemoteJWKSet,
  decodeProtectedHeader,
  jwtVerify,
} from "https://deno.land/x/jose@v4.14.4/index.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import {
  acknowledgeSubscription,
  getGoogleAccessToken,
  getSubscriptionV2,
  GooglePlayApiError,
} from "../_shared/google_play.ts";
import {
  constantTimeEqual,
  detectTrial,
  extractAmount,
  getOrderId,
  mapSubscriptionState,
  pickLineItem,
  resolveBoundUser,
} from "../_shared/play_mapping.ts";

const VALID_PRODUCT_IDS = new Set(["buildera_monthly", "buildera_yearly"]);
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);
let playPubsubWarningShown = false;

async function validatePlayPubSubRequest(req: Request): Promise<boolean> {
  const serviceAccountEmail = Deno.env.get("PLAY_PUBSUB_SERVICE_ACCOUNT") ?? "";
  if (!serviceAccountEmail) {
    if (!playPubsubWarningShown) {
      console.warn(
        "PLAY_PUBSUB_SERVICE_ACCOUNT not set; falling back to query-token validation only.",
      );
      playPubsubWarningShown = true;
    }
    return true;
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const bearerToken = authHeader.replace(/^Bearer\s+/i, "");
  if (!bearerToken) {
    return false;
  }

  const audience = Deno.env.get("PLAY_RTDN_AUDIENCE") ??
    new URL(req.url).origin + new URL(req.url).pathname;

  try {
    const protectedHeader = decodeProtectedHeader(bearerToken);
    const kid = typeof protectedHeader.kid === "string"
      ? protectedHeader.kid
      : null;
    if (!kid) {
      return false;
    }

    const { payload } = await jwtVerify(bearerToken, GOOGLE_JWKS, {
      audience,
      issuer: "https://accounts.google.com",
    });

    const email = payload.email as string | undefined;
    return Boolean(
      email && email === serviceAccountEmail && payload.email_verified === true,
    );
  } catch {
    return false;
  }
}

export async function handleRtdn(
  req: Request,
  deps: {
    supabase?: any;
    google?: {
      getAccessToken?: (saJson: string) => Promise<string>;
      getSubscriptionV2?: (
        args: { packageName: string; token: string; accessToken: string },
      ) => Promise<any>;
      acknowledge?: (
        args: {
          packageName: string;
          subscriptionId: string;
          token: string;
          accessToken: string;
        },
      ) => Promise<boolean>;
    };
    now?: () => Date;
    env?: Record<string, string | undefined>;
    validatePubSubRequest?: (req: Request) => Promise<boolean>;
  } = {},
): Promise<Response> {
  try {
    const url = new URL(req.url);
    const token = url.searchParams.get("token") ?? "";
    const env = deps.env ?? Deno.env.toObject();
    const rtdnToken = env.PLAY_RTDN_TOKEN ?? "";

    if (!rtdnToken || !constantTimeEqual(token, rtdnToken)) {
      return new Response(JSON.stringify({ error: "Unauthorized token" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }

    const isVerified =
      await (deps.validatePubSubRequest ?? validatePlayPubSubRequest)(req);
    if (!isVerified) {
      return new Response(
        JSON.stringify({ error: "Pub/Sub OIDC validation failed" }),
        {
          status: 401,
          headers: { "Content-Type": "application/json" },
        },
      );
    }

    const body = await req.json();
    if (!body.message || !body.message.data) {
      return new Response(
        JSON.stringify({ ok: true, note: "No message data" }),
        { status: 200 },
      );
    }

    const decodedStr = atob(body.message.data);
    const notification = JSON.parse(decodedStr);

    const packageName = env.ANDROID_PACKAGE_NAME ?? "";
    if (notification.packageName && notification.packageName !== packageName) {
      return new Response(
        JSON.stringify({ ok: true, note: "Package name mismatch ignored" }),
        { status: 200 },
      );
    }

    if (notification.testNotification) {
      return new Response(
        JSON.stringify({ ok: true, note: "Test notification received" }),
        { status: 200 },
      );
    }

    const subNotif = notification.subscriptionNotification;
    if (!subNotif || !subNotif.purchaseToken) {
      return new Response(
        JSON.stringify({
          ok: true,
          note: "Non-subscription notification ignored",
        }),
        { status: 200 },
      );
    }

    const purchaseToken = subNotif.purchaseToken;
    const saJson = env.GOOGLE_SERVICE_ACCOUNT_JSON ?? "";
    const supabaseUrl = env.SUPABASE_URL ?? "";
    const supabaseServiceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
    const supabaseAdmin = deps.supabase ??
      createClient(supabaseUrl, supabaseServiceKey);
    const google = deps.google ??
      {
        getAccessToken: getGoogleAccessToken,
        getSubscriptionV2,
        acknowledge: acknowledgeSubscription,
      };
    const accessToken = await google.getAccessToken!(saJson);

    let playSub;
    try {
      playSub = await google.getSubscriptionV2!({
        packageName,
        token: purchaseToken,
        accessToken,
      });
    } catch (err) {
      if (err instanceof GooglePlayApiError) {
        if ([400, 404, 410].includes(err.status)) {
          console.warn(
            "RTDN ignored Google Play token error:",
            err.reason ?? err.message,
          );
          return new Response(
            JSON.stringify({ ok: true, note: "Token no longer valid" }),
            { status: 200 },
          );
        }
        if (
          [409, 429].includes(err.status) || err.status >= 500 || !err.status
        ) {
          console.error(
            "RTDN transient Google Play error:",
            err.reason ?? err.message,
          );
          return new Response(
            JSON.stringify({
              error: "Google Play API temporarily unavailable",
            }),
            { status: 500 },
          );
        }
      }
      throw err;
    }

    playSub.purchaseToken = purchaseToken;
    const lineItem = pickLineItem(playSub, subNotif.subscriptionId);
    const productId = lineItem?.productId ?? subNotif.subscriptionId;

    if (!productId || !VALID_PRODUCT_IDS.has(productId)) {
      console.warn(
        "RTDN notice: Unknown or missing product ID in notification",
      );
      return new Response(
        JSON.stringify({ ok: true, note: "Unknown product ID ignored" }),
        { status: 200 },
      );
    }

    const expiryTime = lineItem?.expiryTime;
    const autoRenewing = lineItem?.autoRenewingPlan != null;
    const ackState = playSub.acknowledgementState ??
      "ACKNOWLEDGEMENT_STATE_UNSPECIFIED";
    const testPurchase = playSub.testPurchase != null;
    const isTrial = detectTrial(playSub, productId);
    const amount = extractAmount(playSub, productId);
    const state = playSub.subscriptionState;
    const mappedStatus = mapSubscriptionState(state);
    const boundUser = await resolveBoundUser(playSub, null, supabaseAdmin);

    if (
      state === "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED" &&
      playSub.linkedPurchaseToken
    ) {
      try {
        const linkedSub = await google.getSubscriptionV2!({
          packageName,
          token: playSub.linkedPurchaseToken,
          accessToken,
        });
        const linkedLineItem = pickLineItem(linkedSub, productId);
        const linkedBoundUser = await resolveBoundUser(
          linkedSub,
          null,
          supabaseAdmin,
        );
        const linkedProductId = linkedLineItem?.productId ?? productId;
        const linkedState = mapSubscriptionState(linkedSub.subscriptionState);

        const linkedRpcArgs = {
          p_purchase_token: playSub.linkedPurchaseToken,
          p_user_id: linkedBoundUser.userId ?? boundUser.userId ?? null,
          p_product_id: linkedProductId,
          p_latest_order_id: getOrderId(linkedSub, linkedProductId),
          p_subscription_state: linkedState,
          p_expiry_time: linkedLineItem?.expiryTime ?? expiryTime,
          p_auto_renewing: linkedLineItem?.autoRenewingPlan != null ||
            autoRenewing,
          p_acknowledgement_state: linkedSub.acknowledgementState ?? ackState,
          p_linked_purchase_token: linkedSub.linkedPurchaseToken ?? null,
          p_test_purchase: linkedSub.testPurchase != null || testPurchase,
          p_is_trial: detectTrial(linkedSub, linkedProductId) || isTrial,
          p_raw: linkedSub,
          p_amount: extractAmount(linkedSub, linkedProductId) || amount || null,
        };
        let { error: linkedApplyError } = await supabaseAdmin.rpc(
          "apply_play_subscription",
          linkedRpcArgs,
        );
        if (linkedApplyError?.code === "23503" && linkedRpcArgs.p_user_id) {
          ({ error: linkedApplyError } = await supabaseAdmin.rpc(
            "apply_play_subscription",
            {
              ...linkedRpcArgs,
              p_user_id: null,
            },
          ));
        }

        const pendingRpcArgs = {
          p_purchase_token: purchaseToken,
          p_user_id: boundUser.userId ?? null,
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
        let { error: pendingApplyError } = await supabaseAdmin.rpc(
          "apply_play_subscription",
          pendingRpcArgs,
        );
        if (pendingApplyError?.code === "23503" && pendingRpcArgs.p_user_id) {
          ({ error: pendingApplyError } = await supabaseAdmin.rpc(
            "apply_play_subscription",
            {
              ...pendingRpcArgs,
              p_user_id: null,
            },
          ));
        }

        if (linkedApplyError || pendingApplyError) {
          const firstError = linkedApplyError ?? pendingApplyError;
          if (
            firstError.code === "P0409" || firstError.message?.includes("P0409")
          ) {
            console.warn("RTDN notice: Token bound to another user (P0409)");
            return new Response(
              JSON.stringify({ ok: true, note: "Token bound to another user" }),
              { status: 200 },
            );
          }
          console.error(
            "RTDN PENDING_PURCHASE_CANCELED RPC Error:",
            firstError.message,
          );
          return new Response(
            JSON.stringify({ error: "Database apply error" }),
            { status: 500 },
          );
        }

        return new Response(
          JSON.stringify({
            ok: true,
            synced: true,
            recovery: "linked_purchase_token",
          }),
          { status: 200 },
        );
      } catch (err) {
        console.warn("RTDN linked recovery failed:", err);
      }
    }

    const rpcArgs = {
      p_purchase_token: purchaseToken,
      p_user_id: boundUser.userId,
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

    let { error: applyError } = await supabaseAdmin.rpc(
      "apply_play_subscription",
      rpcArgs,
    );
    if (applyError?.code === "23503" && boundUser.userId) {
      const retryArgs = { ...rpcArgs, p_user_id: null };
      ({ error: applyError } = await supabaseAdmin.rpc(
        "apply_play_subscription",
        retryArgs,
      ));
    }

    if (applyError) {
      if (
        applyError.code === "P0409" || applyError.message?.includes("P0409")
      ) {
        console.warn("RTDN notice: Token bound to another user (P0409)");
        return new Response(
          JSON.stringify({ ok: true, note: "Token bound to another user" }),
          { status: 200 },
        );
      }
      console.error("RTDN RPC Error:", applyError.message);
      return new Response(JSON.stringify({ error: "Database apply error" }), {
        status: 500,
      });
    }

    if (
      (boundUser.via?.includes("expiredExternalAccountIdentifiers") ||
        boundUser.via?.includes("expiredPurchaseToken") ||
        boundUser.via?.startsWith("play_purchases:")) &&
      ackState === "ACKNOWLEDGEMENT_STATE_PENDING" &&
      ["active", "grace"].includes(mappedStatus)
    ) {
      try {
        await google.acknowledge!({
          packageName,
          subscriptionId: productId,
          token: purchaseToken,
          accessToken,
        });
      } catch (ackErr) {
        console.warn("RTDN acknowledge after bound-user sync failed:", ackErr);
      }
    }

    return new Response(JSON.stringify({ ok: true, synced: true }), {
      status: 200,
    });
  } catch (err: any) {
    console.error("RTDN Error:", err?.message ?? "Unknown error");
    return new Response(JSON.stringify({ error: "RTDN handling error" }), {
      status: 500,
    });
  }
}

if (import.meta.main) {
  serve((req) => handleRtdn(req));
}
