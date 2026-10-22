import { handleDiagnose } from "../play-billing-diagnose/index.ts";
import { generateKeyPair, exportPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

function assertEquals(actual: unknown, expected: unknown, message?: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      message ??
        `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

// Generate a valid extractable PKCS8 private key for testing
const keyPair = await generateKeyPair("RS256", { extractable: true });
const validPkcs8Pem = await exportPKCS8(keyPair.privateKey);

const dummySa = {
  client_email: "test@example.com",
  private_key: validPkcs8Pem,
};

const baseEnv = {
  SUPABASE_URL: "https://supabase.invalid",
  SUPABASE_SERVICE_ROLE_KEY: "service-key",
  GOOGLE_SERVICE_ACCOUNT_JSON: JSON.stringify(dummySa),
  ANDROID_PACKAGE_NAME: "com.solutivostudio.caltax",
  RECONCILE_SECRET: "reconcile-secret",
};

function diagnoseRequest(secret = "reconcile-secret") {
  return new Request("https://edge.invalid/play-billing-diagnose", {
    method: "POST",
    headers: secret
      ? { "x-reconcile-secret": secret, "Content-Type": "application/json" }
      : { "Content-Type": "application/json" },
  });
}

class MockSupabaseDiagnose {
  async rpc(name: string) {
    if (name === "play_billing_health") {
      return {
        data: {
          has_play_purchases_table: true,
          apply_play_subscription_overload_count: 1,
          has_subscription_columns: true,
          has_play_purchases_dead_columns: true,
        },
        error: null,
      };
    }
    return { data: null, error: null };
  }
}

Deno.test("play-billing-diagnose rejects requests without valid x-reconcile-secret", async () => {
  const deps = { env: baseEnv };
  const res1 = await handleDiagnose(diagnoseRequest("wrong-secret"), deps);
  assertEquals(res1.status, 401);
  const body1 = await res1.json();
  assertEquals(body1.code, "unauthorized");

  const res2 = await handleDiagnose(diagnoseRequest(""), deps);
  assertEquals(res2.status, 401);
});

Deno.test("play-billing-diagnose runs full check report successfully with mock dependencies", async () => {
  const supabase = new MockSupabaseDiagnose();
  const mockFetch = (async (url: string) => {
    if (url.includes("/subscriptions")) {
      return new Response(
        JSON.stringify({
          subscriptions: [
            { productId: "buildera_monthly" },
            { productId: "buildera_yearly" },
          ],
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }
    return new Response("not found", { status: 404 });
  }) as typeof fetch;

  const deps = {
    supabase,
    google: { getAccessToken: async () => "mock-access-token" },
    env: baseEnv,
    fetch: mockFetch,
  };

  const response = await handleDiagnose(diagnoseRequest(), deps);
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.ok, true);
  assertEquals(data.env_present, true);
  assertEquals(data.service_account_parse_ok, true);
  assertEquals(data.private_key_import_ok, true);
  assertEquals(data.oauth_token_ok, true);
  assertEquals(data.google_api_ok, true);
  assertEquals(data.subscription_product_ids_found, true);
  assertEquals(data.health.has_play_purchases_table, true);
  assertEquals(data.health.apply_play_subscription_overload_count, 1);
  assertEquals(data.issues.length, 0);
});

Deno.test("play-billing-diagnose reports missing env and invalid database health gracefully", async () => {
  const brokenSupabase = {
    rpc: async () => ({
      data: {
        has_play_purchases_table: false,
        apply_play_subscription_overload_count: 2,
        has_subscription_columns: false,
        has_play_purchases_dead_columns: false,
      },
      error: null,
    }),
  };

  const brokenEnv = {
    ...baseEnv,
    GOOGLE_SERVICE_ACCOUNT_JSON: "{ invalid ",
  };

  const deps = {
    supabase: brokenSupabase,
    google: { getAccessToken: async () => "mock-access-token" },
    env: brokenEnv,
  };

  const response = await handleDiagnose(diagnoseRequest(), deps);
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.ok, false);
  assertEquals(data.service_account_parse_ok, false);
  assertEquals(data.issues.length > 0, true);
});
