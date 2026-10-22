import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";
import { importPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";
import {
  getGoogleAccessToken,
  parseServiceAccountInput,
} from "../_shared/google_play.ts";
import { constantTimeEqual } from "../_shared/play_mapping.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-reconcile-secret",
};

export async function handleDiagnose(
  req: Request,
  deps: {
    supabase?: any;
    google?: {
      getAccessToken?: (saJson: string) => Promise<string>;
    };
    env?: Record<string, string | undefined>;
    fetch?: typeof fetch;
  } = {}
): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const env = deps.env ?? Deno.env.toObject();
  const reconcileSecret = env.RECONCILE_SECRET ?? "";
  const reqSecret = req.headers.get("x-reconcile-secret") ?? "";

  if (!reconcileSecret || !reqSecret || !constantTimeEqual(reqSecret, reconcileSecret)) {
    return new Response(
      JSON.stringify({ error: "Unauthorized", code: "unauthorized" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const issues: string[] = [];
  let envPresent = true;
  let saParseOk = false;
  let pkImportOk = false;
  let oauthTokenOk = false;
  let googleApiOk = false;
  let productsFound = false;
  let healthResult: any = null;

  const supabaseUrl = env.SUPABASE_URL ?? "";
  const supabaseServiceKey = env.SUPABASE_SERVICE_ROLE_KEY ?? "";
  const saJsonInput = env.GOOGLE_SERVICE_ACCOUNT_JSON_B64 || env.GOOGLE_SERVICE_ACCOUNT_JSON || "";
  const packageName = env.ANDROID_PACKAGE_NAME ?? "";

  if (!supabaseUrl || !supabaseServiceKey) {
    envPresent = false;
    issues.push("server_config_missing: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing");
  }
  if (!packageName) {
    envPresent = false;
    issues.push("server_config_missing: ANDROID_PACKAGE_NAME missing");
  }
  if (!saJsonInput) {
    envPresent = false;
    issues.push("server_config_missing: GOOGLE_SERVICE_ACCOUNT_JSON missing");
  }

  let saParsed: any = null;
  if (saJsonInput) {
    try {
      saParsed = parseServiceAccountInput(saJsonInput);
      saParseOk = true;
    } catch (e: any) {
      issues.push(`server_config_json: ${e?.message ?? "Failed to parse Service Account JSON"}`);
    }
  }

  if (saParsed?.private_key) {
    try {
      await importPKCS8(saParsed.private_key, "RS256");
      pkImportOk = true;
    } catch (e: any) {
      issues.push(`server_config_json: Failed to import PKCS8 private key: ${e?.message ?? e}`);
    }
  }

  let accessToken = "";
  if (saParseOk) {
    try {
      const google = deps.google ?? { getAccessToken: getGoogleAccessToken };
      accessToken = await google.getAccessToken!(saJsonInput);
      oauthTokenOk = true;
    } catch (e: any) {
      issues.push(`google_auth: Failed to acquire Google OAuth token: ${e?.message ?? e}`);
    }
  }

  const customFetch = deps.fetch ?? fetch;

  if (oauthTokenOk && packageName && accessToken) {
    try {
      const listUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
        packageName
      )}/subscriptions`;

      const listRes = await customFetch(listUrl, {
        headers: { Authorization: `Bearer ${accessToken}`, Accept: "application/json" },
      });

      if (listRes.ok) {
        googleApiOk = true;
        const listData = await listRes.json();
        const subs = Array.isArray(listData?.subscriptions) ? listData.subscriptions : [];
        const productIds = new Set(subs.map((s: any) => s.productId));
        if (productIds.has("buildera_monthly") && productIds.has("buildera_yearly")) {
          productsFound = true;
        } else {
          issues.push(
            `product_mismatch: Configured subscription IDs buildera_monthly / buildera_yearly not all found in Play Console list (${Array.from(productIds).join(", ")})`
          );
        }
      } else {
        const bodyText = await listRes.text();
        if (listRes.status === 401 || listRes.status === 403) {
          issues.push(`google_auth: Google Publisher API permission denied (${listRes.status}): ${bodyText.slice(0, 200)}`);
        } else if (listRes.status === 404 && bodyText.includes("applicationNotFound")) {
          issues.push(`google_package_mismatch: Application package not found in Play Console: ${packageName}`);
        } else {
          // Fallback check via purchases.subscriptionsv2.get with a dummy token
          const dummyUrl = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
            packageName
          )}/purchases/subscriptionsv2/tokens/dummy_diagnostic_token`;

          const dummyRes = await customFetch(dummyUrl, {
            headers: { Authorization: `Bearer ${accessToken}`, Accept: "application/json" },
          });

          const dummyBody = await dummyRes.text();
          if (
            dummyRes.status === 400 &&
            (dummyBody.includes("invalidToken") || dummyBody.includes("purchaseToken"))
          ) {
            googleApiOk = true;
            productsFound = true;
          } else if (dummyRes.status === 401 || dummyRes.status === 403) {
            issues.push(`google_auth: Google Publisher API permission denied (${dummyRes.status})`);
          } else if (dummyRes.status === 404 && dummyBody.includes("applicationNotFound")) {
            issues.push(`google_package_mismatch: Application package not found in Play Console: ${packageName}`);
          } else {
            issues.push(`google_unavailable: Google Publisher API error (${dummyRes.status}): ${dummyBody.slice(0, 200)}`);
          }
        }
      }
    } catch (e: any) {
      issues.push(`google_unavailable: Exception connecting to Google Publisher API: ${e?.message ?? e}`);
    }
  }

  if (supabaseUrl && supabaseServiceKey) {
    try {
      const supabaseAdmin = deps.supabase ?? createClient(supabaseUrl, supabaseServiceKey);
      const { data, error } = await supabaseAdmin.rpc("play_billing_health");
      if (error) {
        issues.push(`db_persist: RPC play_billing_health failed: ${error.message}`);
      } else {
        healthResult = data;
        if (!data?.has_play_purchases_table) {
          issues.push("db_persist: Table public.play_purchases is missing");
        }
        if (data?.apply_play_subscription_overload_count !== 1) {
          issues.push(`db_persist: Expected exactly 1 overload for apply_play_subscription, found ${data?.apply_play_subscription_overload_count}`);
        }
        if (!data?.has_subscription_columns) {
          issues.push("db_persist: Table public.subscriptions is missing required columns");
        }
        if (!data?.has_play_purchases_dead_columns) {
          issues.push("db_persist: Table public.play_purchases is missing dead_reason or dead_at columns");
        }
      }
    } catch (e: any) {
      issues.push(`db_persist: Exception querying play_billing_health: ${e?.message ?? e}`);
    }
  }

  const allPassed =
    envPresent &&
    saParseOk &&
    pkImportOk &&
    oauthTokenOk &&
    googleApiOk &&
    productsFound &&
    healthResult?.has_play_purchases_table === true &&
    healthResult?.apply_play_subscription_overload_count === 1 &&
    healthResult?.has_subscription_columns === true &&
    healthResult?.has_play_purchases_dead_columns === true;

  return new Response(
    JSON.stringify({
      ok: allPassed,
      env_present: envPresent,
      service_account_parse_ok: saParseOk,
      private_key_import_ok: pkImportOk,
      oauth_token_ok: oauthTokenOk,
      google_api_ok: googleApiOk,
      subscription_product_ids_found: productsFound,
      health: healthResult,
      issues,
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

if (import.meta.main) {
  serve((req) => handleDiagnose(req));
}
