import { handleSync } from "../sync-play-subscription/index.ts";
import { GooglePlayApiError } from "../_shared/google_play.ts";
import { generateKeyPair, exportPKCS8 } from "https://deno.land/x/jose@v4.14.4/index.ts";

function assertEquals(actual: unknown, expected: unknown, message?: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      message ??
        `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

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
};

function syncRequest(authorization = "Bearer jwt") {
  return new Request("https://edge.invalid/sync-play-subscription", {
    method: "POST",
    headers: authorization
      ? { Authorization: authorization, "Content-Type": "application/json" }
      : { "Content-Type": "application/json" },
  });
}

class MockSupabaseSync {
  auth = {
    getUser: async (token: string) =>
      token === "jwt"
        ? { data: { user: { id: "user-1" } }, error: null }
        : { data: { user: null }, error: new Error("invalid token") },
  };

  purchases: any[] = [];
  subscription: any = {
    user_id: "user-1",
    plan_type: "monthly",
    status: "active",
    expires_at: "2026-11-01T00:00:00.000Z",
  };
  deadUpdates: any[] = [];

  from(table: string) {
    const self = this;
    if (table === "subscriptions") {
      return {
        select: (_cols: string) => ({
          eq: (_col: string, _val: string) => ({
            maybeSingle: async () => ({ data: self.subscription, error: null }),
            then: (resolve: any) => resolve({ data: [self.subscription], error: null }),
          }),
        }),
      };
    }
    if (table === "play_purchases") {
      return {
        select: (_cols: string) => ({
          eq: (_col1: string, val1: string) => ({
            maybeSingle: async () => ({ data: { user_id: "user-1" }, error: null }),
            eq: (_col2: string, _val2: boolean) => ({
              is: (_col3: string, _val3: any) => ({
                order: (_col4: string, _opts: any) => ({
                  limit: async (_count: number) => ({ data: self.purchases, error: null }),
                }),
              }),
            }),
          }),
        }),
        update: (data: any) => ({
          eq: (col: string, val: string) => {
            self.deadUpdates.push({ data, col, val });
            return Promise.resolve({ data: null, error: null });
          },
        }),
      };
    }
    return {
      select: () => ({
        eq: () => ({
          maybeSingle: async () => ({ data: null, error: null }),
          then: (resolve: any) => resolve({ data: [], error: null }),
        }),
      }),
    };
  }

  async rpc(name: string, args?: any) {
    if (name === "apply_play_subscription") {
      this.subscription = {
        user_id: args.p_user_id ?? "user-1",
        plan_type: "monthly",
        status: args.p_subscription_state ?? "active",
        expires_at: args.p_expiry_time,
      };
      return { data: { status: "success" }, error: null };
    }
    return { data: null, error: null };
  }
}

Deno.test("sync-play-subscription rejects invalid or missing auth header with 401", async () => {
  const deps = { env: baseEnv };
  const res1 = await handleSync(syncRequest(""), deps);
  assertEquals(res1.status, 401);
  assertEquals((await res1.json()).code, "unauthorized");

  const res2 = await handleSync(syncRequest("Bearer invalid-jwt"), {
    ...deps,
    supabase: new MockSupabaseSync(),
  });
  assertEquals(res2.status, 401);
  assertEquals((await res2.json()).code, "unauthorized");
});

Deno.test("sync-play-subscription returns current state when no play_purchases exist", async () => {
  const supabase = new MockSupabaseSync();
  supabase.purchases = [];

  const response = await handleSync(syncRequest(), {
    supabase,
    env: baseEnv,
  });

  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.ok, true);
  assertEquals(data.status, "active");
  assertEquals(data.plan, "monthly");
  assertEquals(data.rate_limited, false);
});

Deno.test("sync-play-subscription respects 60s rate limit based on last_synced_at", async () => {
  const supabase = new MockSupabaseSync();
  const now = new Date("2026-10-22T10:00:00.000Z");
  supabase.purchases = [
    {
      purchase_token: "token-1",
      user_id: "user-1",
      product_id: "buildera_monthly",
      last_synced_at: new Date("2026-10-22T09:59:30.000Z").toISOString(), // 30s ago (< 60s)
    },
  ];

  let googleCalled = false;
  const deps = {
    supabase,
    google: {
      getAccessToken: async () => "mock-token",
      getSubscriptionV2: async () => {
        googleCalled = true;
        return {};
      },
    },
    now: () => now,
    env: baseEnv,
  };

  const response = await handleSync(syncRequest(), deps);
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.ok, true);
  assertEquals(data.rate_limited, true);
  assertEquals(googleCalled, false);
});

Deno.test("sync-play-subscription updates subscription on renewal and marks 410 dead tokens", async () => {
  const supabase = new MockSupabaseSync();
  const now = new Date("2026-10-22T10:00:00.000Z");
  supabase.purchases = [
    {
      purchase_token: "token-1",
      user_id: "user-1",
      product_id: "buildera_monthly",
      last_synced_at: new Date("2026-10-22T08:00:00.000Z").toISOString(), // > 60s ago
    },
  ];

  const playSub = {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    lineItems: [
      {
        productId: "buildera_monthly",
        expiryTime: "2026-11-22T10:00:00.000Z",
      },
    ],
  };

  const deps = {
    supabase,
    google: {
      getAccessToken: async () => "mock-token",
      getSubscriptionV2: async () => playSub,
    },
    now: () => now,
    env: baseEnv,
  };

  const response = await handleSync(syncRequest(), deps);
  assertEquals(response.status, 200);
  const data = await response.json();
  assertEquals(data.ok, true);
  assertEquals(data.expires_at, "2026-11-22T10:00:00.000Z");

  // Test 410 dead token
  const deadSupabase = new MockSupabaseSync();
  deadSupabase.purchases = [
    {
      purchase_token: "dead-token",
      user_id: "user-1",
      product_id: "buildera_monthly",
      last_synced_at: new Date("2026-10-22T08:00:00.000Z").toISOString(),
    },
  ];

  const deadDeps = {
    supabase: deadSupabase,
    google: {
      getAccessToken: async () => "mock-token",
      getSubscriptionV2: async () => {
        throw new GooglePlayApiError(410, "purchaseTokenNoLongerValid", "purchaseTokenNoLongerValid");
      },
    },
    now: () => now,
    env: baseEnv,
  };

  const deadRes = await handleSync(syncRequest(), deadDeps);
  assertEquals(deadRes.status, 200);
  assertEquals(deadSupabase.deadUpdates.length, 1);
  assertEquals(deadSupabase.deadUpdates[0].data.dead_reason, "purchaseTokenNoLongerValid");
});
