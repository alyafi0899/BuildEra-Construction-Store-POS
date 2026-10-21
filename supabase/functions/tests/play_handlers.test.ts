import { handleVerify } from "../verify-play-purchase/index.ts";
import { handleRtdn } from "../play-rtdn/index.ts";
import { handleReconcile } from "../reconcile-play-subscriptions/index.ts";
import { GooglePlayApiError } from "../_shared/google_play.ts";
import { resolveBoundUser } from "../_shared/play_mapping.ts";

function assert(
  condition: unknown,
  message = "Assertion failed",
): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown, message?: string) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      message ??
        `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

type RpcResult = { data?: unknown; error?: any };

class MockSupabase {
  auth = {
    getUser: async (_token: string) => ({
      data: { user: { id: "user-1" } },
      error: null,
    }),
  };
  rpcCalls: Array<{ name: string; args?: any }> = [];
  rpcResults: RpcResult[] = [];
  queryCalls: QueryBuilder[] = [];
  queryResults: any[] = [[], [], []];
  queryErrors: Record<string, any> = {};
  lookupByToken: Record<string, any> = {};
  lookupErrors: Record<string, any> = {};

  from(table: string) {
    const query = new QueryBuilder(this, table);
    this.queryCalls.push(query);
    return query;
  }

  async rpc(name: string, args?: any): Promise<RpcResult> {
    this.rpcCalls.push({ name, args });
    return this.rpcResults.shift() ??
      {
        data: name === "get_server_time" ? "2026-10-19T00:00:00.000Z" : null,
        error: null,
      };
  }

  resolveLookup(query: QueryBuilder) {
    const token = query.filters.find(([column]) => column === "purchase_token")
      ?.[1] as string | undefined;
    return {
      data: token ? this.lookupByToken[token] ?? null : null,
      error: token ? this.lookupErrors[token] ?? null : null,
    };
  }

  resolveQuery(query: QueryBuilder) {
    if (query.updateValue !== undefined) {
      query.updateResult = { data: null, error: null };
      return query.updateResult;
    }
    const result = this.queryResults.shift() ?? [];
    if (!Array.isArray(result)) return result;
    return {
      data: result,
      error: this.queryErrors[query.table] ?? null,
    };
  }
}

class QueryBuilder {
  filters: Array<[string, unknown]> = [];
  updateValue?: unknown;
  updateResult?: any;
  constructor(readonly mock: MockSupabase, readonly table: string) {}
  select(_columns: string) {
    return this;
  }
  eq(column: string, value: unknown) {
    this.filters.push([column, value]);
    return this;
  }
  is(column: string, value: unknown) {
    this.filters.push([column, value]);
    return this;
  }
  gte(column: string, value: unknown) {
    this.filters.push([column, value]);
    return this;
  }
  lte(column: string, value: unknown) {
    this.filters.push([column, value]);
    return this;
  }
  in(column: string, value: unknown) {
    this.filters.push([column, value]);
    return this;
  }
  order(_column: string, _options: unknown) {
    return this;
  }
  limit(_count: number) {
    return this;
  }
  update(value: unknown) {
    this.updateValue = value;
    return this;
  }
  maybeSingle() {
    return Promise.resolve(this.mock.resolveLookup(this));
  }
  then<TResult1 = any, TResult2 = never>(
    onfulfilled?: ((value: any) => TResult1 | PromiseLike<TResult1>) | null,
    onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null,
  ) {
    return Promise.resolve(this.mock.resolveQuery(this)).then(
      onfulfilled,
      onrejected,
    );
  }
}

const baseSubscription = (overrides: Record<string, any> = {}): any => ({
  subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
  acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
  externalAccountIdentifiers: { obfuscatedExternalAccountId: "user-1" },
  lineItems: [{
    productId: "buildera_monthly",
    expiryTime: "2026-11-19T00:00:00.000Z",
    autoRenewingPlan: { recurringPrice: { units: "10", nanos: 0 } },
    latestSuccessfulOrderId: "order-1",
  }],
  ...overrides,
});

const baseEnv = {
  SUPABASE_URL: "https://supabase.invalid",
  SUPABASE_SERVICE_ROLE_KEY: "service-key",
  GOOGLE_SERVICE_ACCOUNT_JSON: "{}",
  ANDROID_PACKAGE_NAME: "com.solutivostudio.caltax",
  PLAY_RTDN_TOKEN: "rtdn-secret",
  RECONCILE_SECRET: "reconcile-secret",
};

function verifyRequest(
  body: unknown = { purchaseToken: "token-1", productId: "buildera_monthly" },
  authorization = "Bearer jwt",
) {
  return new Request("https://edge.invalid/verify", {
    method: "POST",
    headers: authorization
      ? { Authorization: authorization, "Content-Type": "application/json" }
      : { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function rtdnRequest(notification: unknown, queryToken = "rtdn-secret") {
  return new Request(`https://edge.invalid/play-rtdn?token=${queryToken}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: { data: btoa(JSON.stringify(notification)) },
    }),
  });
}

const googleFor = (playSub = baseSubscription(), options: {
  subscription?: (token: string) => any | Promise<any>;
  accessToken?: () => Promise<string>;
  acknowledge?: (args: {
    packageName: string;
    subscriptionId: string;
    token: string;
    accessToken: string;
  }) => Promise<boolean>;
} = {}) => ({
  getAccessToken: options.accessToken ?? (async () => "access-token"),
  getSubscriptionV2: async ({ token }: { token: string }) =>
    options.subscription ? options.subscription(token) : playSub,
  acknowledge: options.acknowledge ?? (async () => true),
});

Deno.test("verify rejects missing auth and invalid product before Play access", async () => {
  const supabase = new MockSupabase();
  const google = googleFor();
  const deps = { supabase, google, env: baseEnv };
  assertEquals(
    (await handleVerify(verifyRequest(undefined, ""), deps)).status,
    401,
  );
  assertEquals(
    (await handleVerify(
      verifyRequest({ purchaseToken: "t", productId: "other" }),
      deps,
    )).status,
    400,
  );
  assertEquals(supabase.rpcCalls.length, 0);
});

Deno.test("verify persists a bound subscription and returns mapped entitlement", async () => {
  const supabase = new MockSupabase();
  const response = await handleVerify(verifyRequest(), {
    supabase,
    google: googleFor(),
    env: baseEnv,
  });
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    ok: true,
    plan: "monthly",
    status: "active",
    expires_at: "2026-11-19T00:00:00.000Z",
    is_trial: false,
    access: true,
    ack_state: "ACKNOWLEDGEMENT_STATE_PENDING",
    server_time: "2026-10-19T00:00:00.000Z",
  });
  assertEquals(supabase.rpcCalls[0].name, "apply_play_subscription");
  assertEquals(supabase.rpcCalls[0].args.p_user_id, "user-1");
});

Deno.test("verify rejects an external account identifier bound to another user", async () => {
  const response = await handleVerify(verifyRequest(), {
    supabase: new MockSupabase(),
    google: googleFor(baseSubscription({
      externalAccountIdentifiers: { obfuscatedExternalAccountId: "user-2" },
    })),
    env: baseEnv,
  });
  assertEquals(response.status, 403);
});

Deno.test("verify allows initial purchase without externalAccountIdentifiers and binds to JWT user", async () => {
  const supabase = new MockSupabase();
  const unidentSub = baseSubscription();
  delete unidentSub.externalAccountIdentifiers;

  const response = await handleVerify(verifyRequest(), {
    supabase,
    google: googleFor(unidentSub),
    env: baseEnv,
  });
  assertEquals(response.status, 200);
  assertEquals(supabase.rpcCalls[0].name, "apply_play_subscription");
  assertEquals(supabase.rpcCalls[0].args.p_user_id, "user-1");
});

Deno.test("verify rejects a previously bound token and a Play response without line items", async () => {
  const boundDb = new MockSupabase();
  boundDb.lookupByToken["token-1"] = { user_id: "user-2" };
  const bound = await handleVerify(verifyRequest(), {
    supabase: boundDb,
    google: googleFor(),
    env: baseEnv,
  });
  assertEquals(bound.status, 409);

  const noLineItems = await handleVerify(verifyRequest(), {
    supabase: new MockSupabase(),
    google: googleFor({ lineItems: [] }),
    env: baseEnv,
  });
  assertEquals(noLineItems.status, 400);
});

Deno.test("verify retries an apply foreign-key error with a null user and reports token conflicts", async () => {
  const supabase = new MockSupabase();
  supabase.rpcResults = [
    { error: { code: "23503", message: "user foreign key missing" } },
    { error: null },
    { data: "2026-10-19T00:00:00.000Z", error: null },
  ];
  const response = await handleVerify(verifyRequest(), {
    supabase,
    google: googleFor(),
    env: baseEnv,
  });
  assertEquals(response.status, 200);
  assertEquals(supabase.rpcCalls[1].args.p_user_id, null);

  const conflictSupabase = new MockSupabase();
  conflictSupabase.rpcResults = [{
    error: { code: "P0409", message: "P0409" },
  }];
  const conflict = await handleVerify(verifyRequest(), {
    supabase: conflictSupabase,
    google: googleFor(),
    env: baseEnv,
  });
  assertEquals(conflict.status, 409);
});

Deno.test("verify recovers a canceled pending replacement through its linked purchase token", async () => {
  const supabase = new MockSupabase();
  const google = googleFor(undefined, {
    subscription: async (token) =>
      token === "token-1"
        ? baseSubscription({
          subscriptionState: "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
          linkedPurchaseToken: "old-token",
        })
        : baseSubscription(),
  });
  const response = await handleVerify(verifyRequest(), {
    supabase,
    google,
    env: baseEnv,
  });
  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "none");
  assertEquals(
    supabase.rpcCalls.slice(0, 2).map(({ args }) => args.p_purchase_token),
    ["old-token", "token-1"],
  );
  assertEquals(supabase.rpcCalls[1].args.p_subscription_state, "none");
});

Deno.test("verify acknowledges pending purchases only when resolved through a rebind source", async () => {
  let ackCount = 0;
  const sub = baseSubscription({
    externalAccountIdentifiers: undefined,
    outOfAppPurchaseContext: {
      expiredExternalAccountIdentifiers: {
        obfuscatedExternalAccountId: "user-1",
      },
    },
  });
  const response = await handleVerify(verifyRequest(), {
    supabase: new MockSupabase(),
    google: googleFor(sub, {
      acknowledge: async () => {
        ackCount++;
        return true;
      },
    }),
    env: baseEnv,
  });
  assertEquals(response.status, 200);
  assertEquals(ackCount, 1);

  let ordinaryAckCount = 0;
  const ordinary = await handleVerify(verifyRequest(), {
    supabase: new MockSupabase(),
    google: googleFor(baseSubscription(), {
      acknowledge: async () => {
        ordinaryAckCount++;
        return true;
      },
    }),
    env: baseEnv,
  });
  assertEquals(ordinary.status, 200);
  assertEquals(ordinaryAckCount, 0);
});

Deno.test("verify accepts a JWT-bound out-of-app re-subscribe and acknowledges it", async () => {
  let acknowledged: unknown[] = [];
  const response = await handleVerify(verifyRequest(), {
    supabase: new MockSupabase(),
    google: googleFor(
      baseSubscription({
        externalAccountIdentifiers: undefined,
        outOfAppPurchaseContext: {
          expiredExternalAccountIdentifiers: {
            obfuscatedExternalAccountId: "user-1",
          },
        },
      }),
      {
        acknowledge: async (args: any) => {
          acknowledged.push(args);
          return true;
        },
      },
    ),
    env: baseEnv,
  });
  assertEquals(response.status, 200);
  assertEquals(acknowledged.length, 1);
  assertEquals(acknowledged[0], {
    packageName: baseEnv.ANDROID_PACKAGE_NAME,
    subscriptionId: "buildera_monthly",
    token: "token-1",
    accessToken: "access-token",
  });
});

Deno.test("verify maps invalid Play tokens to 400 and transient Play failures to 503", async () => {
  for (const status of [400, 404, 410]) {
    const invalid = await handleVerify(verifyRequest(), {
      supabase: new MockSupabase(),
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(status, "invalidToken", "invalidToken");
        },
      }),
      env: baseEnv,
    });
    assertEquals(
      invalid.status,
      400,
      `Expected Google ${status} to map to HTTP 400`,
    );
  }
  for (const status of [409, 429, 500, 503]) {
    const transient = await handleVerify(verifyRequest(), {
      supabase: new MockSupabase(),
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(
            status,
            "temporarilyUnavailable",
            "unavailable",
          );
        },
      }),
      env: baseEnv,
    });
    assertEquals(
      transient.status,
      503,
      `Expected Google ${status} to map to HTTP 503`,
    );
  }
});

Deno.test("RTDN authenticates with its shared token and ignores non-applicable notifications", async () => {
  const supabase = new MockSupabase();
  const deps = {
    supabase,
    google: googleFor(),
    env: baseEnv,
    validatePubSubRequest: async () => true,
  };
  assertEquals(
    (await handleRtdn(rtdnRequest({}), {
      ...deps,
      env: { ...baseEnv, PLAY_RTDN_TOKEN: "" },
    })).status,
    401,
  );
  assertEquals(
    (await handleRtdn(rtdnRequest({}, "bad-token"), deps)).status,
    401,
  );
  const mismatch = await handleRtdn(
    rtdnRequest({ packageName: "other.package" }),
    deps,
  );
  assertEquals(mismatch.status, 200);
  assertEquals((await mismatch.json()).note, "Package name mismatch ignored");
  const testNotification = await handleRtdn(
    rtdnRequest({ testNotification: {} }),
    deps,
  );
  assertEquals(
    (await testNotification.json()).note,
    "Test notification received",
  );
  const noPurchase = await handleRtdn(
    rtdnRequest({ packageName: baseEnv.ANDROID_PACKAGE_NAME }),
    deps,
  );
  assertEquals(
    (await noPurchase.json()).note,
    "Non-subscription notification ignored",
  );
  const badOidc = await handleRtdn(rtdnRequest({}), {
    ...deps,
    env: {
      ...baseEnv,
      PLAY_PUBSUB_SERVICE_ACCOUNT: "push@project.iam.gserviceaccount.com",
    },
    validatePubSubRequest: async () => false,
  });
  assertEquals(badOidc.status, 401);
  assertEquals(supabase.rpcCalls.length, 0);
});

Deno.test("RTDN rejects malformed OIDC bearer tokens when OIDC identity validation is configured", async () => {
  const previousEmail = Deno.env.get("PLAY_PUBSUB_SERVICE_ACCOUNT");
  Deno.env.set(
    "PLAY_PUBSUB_SERVICE_ACCOUNT",
    "push@project.iam.gserviceaccount.com",
  );
  try {
    const response = await handleRtdn(
      new Request("https://edge.invalid/play-rtdn?token=rtdn-secret", {
        method: "POST",
        headers: {
          Authorization: "Bearer malformed",
          "Content-Type": "application/json",
        },
        body: "{}",
      }),
      {
        supabase: new MockSupabase(),
        google: googleFor(),
        env: baseEnv,
      },
    );
    assertEquals(response.status, 401);
    assertEquals(
      (await response.json()).error,
      "Pub/Sub OIDC validation failed",
    );
  } finally {
    if (previousEmail === undefined) {
      Deno.env.delete("PLAY_PUBSUB_SERVICE_ACCOUNT");
    } else {
      Deno.env.set("PLAY_PUBSUB_SERVICE_ACCOUNT", previousEmail);
    }
  }
});

Deno.test("RTDN synchronizes out-of-app re-subscribes, retries 23503 without user, and acknowledges eligible rebinds", async () => {
  const sub = baseSubscription({
    externalAccountIdentifiers: undefined,
    outOfAppPurchaseContext: {
      expiredExternalAccountIdentifiers: {
        obfuscatedExternalAccountId: "user-1",
      },
    },
  });
  const supabase = new MockSupabase();
  supabase.rpcResults = [
    { error: { code: "23503", message: "missing user" } },
    { error: null },
  ];
  let ackCount = 0;
  const response = await handleRtdn(
    rtdnRequest({
      packageName: baseEnv.ANDROID_PACKAGE_NAME,
      subscriptionNotification: {
        purchaseToken: "token-1",
        subscriptionId: "buildera_monthly",
      },
    }),
    {
      supabase,
      google: googleFor(sub, {
        acknowledge: async () => {
          ackCount++;
          return true;
        },
      }),
      env: baseEnv,
      validatePubSubRequest: async () => true,
    },
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).synced, true);
  assertEquals(supabase.rpcCalls[1].args.p_user_id, null);
  assertEquals(ackCount, 1);
});

Deno.test("RTDN suppresses token conflicts and treats transient Google errors as retryable", async () => {
  const notification = {
    packageName: baseEnv.ANDROID_PACKAGE_NAME,
    subscriptionNotification: {
      purchaseToken: "token-1",
      subscriptionId: "buildera_monthly",
    },
  };
  const conflict = await handleRtdn(rtdnRequest(notification), {
    supabase: Object.assign(new MockSupabase(), {
      rpcResults: [{ error: { code: "P0409", message: "P0409" } }],
    }),
    google: googleFor(),
    env: baseEnv,
    validatePubSubRequest: async () => true,
  });
  assertEquals(conflict.status, 200);
  assertEquals((await conflict.json()).note, "Token bound to another user");

  const transient = await handleRtdn(rtdnRequest(notification), {
    supabase: new MockSupabase(),
    google: googleFor(undefined, {
      subscription: async () => {
        throw new GooglePlayApiError(503, "unavailable", "unavailable");
      },
    }),
    env: baseEnv,
    validatePubSubRequest: async () => true,
  });
  assertEquals(transient.status, 500);
});

Deno.test("RTDN recovers canceled pending replacements with 23503 fallbacks and ignores invalid or unknown tokens/products", async () => {
  const notification = {
    packageName: baseEnv.ANDROID_PACKAGE_NAME,
    subscriptionNotification: {
      purchaseToken: "token-1",
      subscriptionId: "buildera_monthly",
    },
  };
  const supabase = new MockSupabase();
  supabase.rpcResults = [
    { error: { code: "23503", message: "linked user foreign key missing" } },
    { error: null },
    { error: { code: "23503", message: "pending user foreign key missing" } },
    { error: null },
  ];
  const recovery = await handleRtdn(rtdnRequest(notification), {
    supabase,
    google: googleFor(undefined, {
      subscription: async (token) =>
        token === "token-1"
          ? baseSubscription({
            subscriptionState: "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
            linkedPurchaseToken: "old-token",
          })
          : baseSubscription(),
    }),
    env: baseEnv,
    validatePubSubRequest: async () => true,
  });
  assertEquals(recovery.status, 200);
  assertEquals((await recovery.json()).recovery, "linked_purchase_token");
  assertEquals(
    supabase.rpcCalls.map(({ args }) => args.p_purchase_token),
    ["old-token", "old-token", "token-1", "token-1"],
  );
  assertEquals(supabase.rpcCalls[1].args.p_user_id, null);
  assertEquals(supabase.rpcCalls[3].args.p_user_id, null);

  const unknownProduct = await handleRtdn(
    rtdnRequest({
      ...notification,
      subscriptionNotification: {
        purchaseToken: "token-1",
        subscriptionId: "unknown_product",
      },
    }),
    {
      supabase: new MockSupabase(),
      google: googleFor(baseSubscription({
        lineItems: [{ productId: "unknown_product" }],
      })),
      env: baseEnv,
      validatePubSubRequest: async () => true,
    },
  );
  assertEquals(
    (await unknownProduct.json()).note,
    "Unknown product ID ignored",
  );

  const goneToken = await handleRtdn(rtdnRequest(notification), {
    supabase: new MockSupabase(),
    google: googleFor(undefined, {
      subscription: async () => {
        throw new GooglePlayApiError(410, "gone", "gone");
      },
    }),
    env: baseEnv,
    validatePubSubRequest: async () => true,
  });
  assertEquals((await goneToken.json()).note, "Token no longer valid");

  for (const status of [400, 404, 410]) {
    const gone = await handleRtdn(rtdnRequest(notification), {
      supabase: new MockSupabase(),
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(status, "invalidToken", "invalidToken");
        },
      }),
      env: baseEnv,
      validatePubSubRequest: async () => true,
    });
    assertEquals(
      gone.status,
      200,
      `Expected Google ${status} to be acknowledged with HTTP 200`,
    );
    assertEquals((await gone.json()).note, "Token no longer valid");
  }
  for (const status of [500, 503]) {
    const retryable = await handleRtdn(rtdnRequest(notification), {
      supabase: new MockSupabase(),
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(status, "unavailable", "unavailable");
        },
      }),
      env: baseEnv,
      validatePubSubRequest: async () => true,
    });
    assertEquals(
      retryable.status,
      500,
      `Expected Google ${status} to produce HTTP 500`,
    );
  }
});

const reconcileRequest = (secret = "reconcile-secret") =>
  new Request("https://edge.invalid/reconcile", {
    method: "POST",
    headers: { "x-reconcile-secret": secret },
  });

const reconcileDeps = (
  supabase: MockSupabase,
  overrides: Record<string, any> = {},
) => ({
  supabase,
  google: googleFor(),
  env: baseEnv,
  now: () => new Date("2026-10-19T00:00:00.000Z"),
  sleep: async (_milliseconds: number) => {},
  ...overrides,
});

function reconcileItem(overrides: Record<string, any> = {}) {
  return {
    purchase_token: "reconcile-token",
    user_id: "user-1",
    product_id: "buildera_monthly",
    expiry_time: "2026-10-20T00:00:00.000Z",
    auto_renewing: true,
    acknowledgement_state: "ACKNOWLEDGEMENT_STATE_PENDING",
    test_purchase: false,
    latest_order_id: "old-order",
    created_at: "2026-10-17T00:00:00.000Z",
    raw: {},
    ...overrides,
  };
}

Deno.test("reconcile requires its secret and excludes dead or superseded rows from every target query", async () => {
  const supabase = new MockSupabase();
  const unauthorized = await handleReconcile(
    reconcileRequest("wrong"),
    reconcileDeps(supabase),
  );
  assertEquals(unauthorized.status, 401);
  assertEquals(supabase.queryCalls.length, 0);

  supabase.queryResults = [[], [], []];
  const response = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(supabase),
  );
  assertEquals(response.status, 200);
  assertEquals(supabase.queryCalls.length, 3);
  for (const query of supabase.queryCalls) {
    assert(
      query.filters.some(([column, value]) =>
        column === "dead_reason" && value === null
      ),
    );
    assert(
      query.filters.some(([column, value]) =>
        column === "superseded" && value === false
      ),
    );
  }
});

Deno.test("reconcile returns 500 when a target selection fails", async () => {
  const supabase = new MockSupabase();
  supabase.queryErrors.play_purchases = {
    message: "temporary database failure",
  };
  const response = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(supabase),
  );
  assertEquals(response.status, 500);
  assertEquals((await response.json()).error, "Reconcile process failed");
});

Deno.test("reconcile marks known-dead Play tokens and retries database 23503 with a null user", async () => {
  const deadDb = new MockSupabase();
  deadDb.queryResults = [[reconcileItem()], [], []];
  const deadResponse = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(deadDb, {
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(
            410,
            "purchaseTokenNoLongerValid",
            "dead",
          );
        },
      }),
    }),
  );
  assertEquals(deadResponse.status, 200);
  assertEquals(await deadResponse.json(), {
    ok: true,
    processed: 0,
    failed: 0,
    skipped: 1,
    acknowledged: 0,
  });
  const deadUpdate = deadDb.queryCalls.find((query) =>
    query.updateValue !== undefined
  );
  assertEquals(
    (deadUpdate?.updateValue as any)?.dead_reason,
    "purchaseTokenNoLongerValid",
  );
  assertEquals(
    (deadUpdate?.updateValue as any)?.dead_at,
    "2026-10-19T00:00:00.000Z",
  );

  const unavailableDb = new MockSupabase();
  unavailableDb.queryResults = [
    [reconcileItem({ purchase_token: "unavailable-token" })],
    [],
    [],
  ];
  const unavailableResponse = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(unavailableDb, {
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(
            410,
            "subscriptionNoLongerAvailable",
            "dead",
          );
        },
      }),
    }),
  );
  assertEquals((await unavailableResponse.json()).skipped, 1);
  const unavailableUpdate = unavailableDb.queryCalls.find((query) =>
    query.updateValue !== undefined
  );
  assertEquals(
    (unavailableUpdate?.updateValue as any)?.dead_reason,
    "subscriptionNoLongerAvailable",
  );

  const retryDb = new MockSupabase();
  retryDb.queryResults = [
    [reconcileItem({
      acknowledgement_state: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      created_at: "2026-10-18T12:00:00.000Z",
    })],
    [],
    [],
  ];
  retryDb.rpcResults = [{ error: { code: "23503" } }, { error: null }];
  const retryResponse = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(retryDb),
  );
  assertEquals(retryResponse.status, 200);
  assertEquals(await retryResponse.json(), {
    ok: true,
    processed: 1,
    failed: 0,
    skipped: 0,
    acknowledged: 0,
  });
  assertEquals(retryDb.rpcCalls[1].args.p_user_id, null);
});

Deno.test("reconcile acknowledge backstop requires age over 24h, an owning user, pending ack, and active or grace status", async () => {
  const cases = [
    reconcileItem({
      purchase_token: "eligible",
      created_at: "2026-10-17T00:00:00.000Z",
    }),
    reconcileItem({
      purchase_token: "recent",
      created_at: "2026-10-18T12:00:00.000Z",
    }),
    reconcileItem({
      purchase_token: "exactly-24h",
      created_at: "2026-10-18T00:00:00.000Z",
    }),
    reconcileItem({
      purchase_token: "unowned",
      user_id: null,
      created_at: "2026-10-17T00:00:00.000Z",
    }),
    reconcileItem({
      purchase_token: "canceled",
      created_at: "2026-10-17T00:00:00.000Z",
    }),
  ];
  const supabase = new MockSupabase();
  supabase.queryResults = [cases, [], []];
  let acknowledgeCalls: string[] = [];
  const response = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(supabase, {
      google: googleFor(undefined, {
        subscription: async (token: string) =>
          baseSubscription({
            subscriptionState: token === "canceled"
              ? "SUBSCRIPTION_STATE_CANCELED"
              : "SUBSCRIPTION_STATE_ACTIVE",
            externalAccountIdentifiers: undefined,
            acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
          }),
        acknowledge: async () => {
          acknowledgeCalls.push("ack");
          return true;
        },
      }),
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(acknowledgeCalls.length, 1);
  assertEquals((await response.json()).acknowledged, 1);
});

Deno.test("reconcile skips P0409 conflicts and stops after five invalid Google configurations", async () => {
  const conflictDb = new MockSupabase();
  conflictDb.queryResults = [
    [reconcileItem({
      acknowledgement_state: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
      created_at: "2026-10-18T12:00:00.000Z",
    })],
    [],
    [],
  ];
  conflictDb.rpcResults = [{ error: { code: "P0409", message: "P0409" } }];
  const conflictResponse = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(conflictDb),
  );
  assertEquals(await conflictResponse.json(), {
    ok: true,
    processed: 0,
    failed: 0,
    skipped: 1,
    acknowledged: 0,
  });

  const failingDb = new MockSupabase();
  failingDb.queryResults = [
    [
      reconcileItem({ purchase_token: "bad-1" }),
      reconcileItem({ purchase_token: "bad-2" }),
      reconcileItem({ purchase_token: "bad-3" }),
      reconcileItem({ purchase_token: "bad-4" }),
      reconcileItem({ purchase_token: "bad-5" }),
    ],
    [],
    [],
  ];
  const failure = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(failingDb, {
      google: googleFor(undefined, {
        subscription: async () => {
          throw new GooglePlayApiError(400, "purchaseTokenMismatch", "invalid");
        },
      }),
    }),
  );
  assertEquals(failure.status, 500);
  assertEquals(
    (await failure.json()).error,
    "Periksa konfigurasi Google (package name / izin service account)",
  );
  assertEquals(
    failingDb.queryCalls.some((query) => query.updateValue !== undefined),
    false,
    "A 400 purchaseTokenMismatch must not mark the token dead",
  );
});

Deno.test("reconcile resets consecutive Google failures after a successful lookup", async () => {
  const supabase = new MockSupabase();
  supabase.queryResults = [
    [
      ...Array.from(
        { length: 4 },
        (_, index) => reconcileItem({ purchase_token: `before-${index}` }),
      ),
      reconcileItem({
        purchase_token: "success",
        acknowledgement_state: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
        created_at: "2026-10-18T12:00:00.000Z",
      }),
      ...Array.from(
        { length: 4 },
        (_, index) => reconcileItem({ purchase_token: `after-${index}` }),
      ),
    ],
    [],
    [],
  ];
  const response = await handleReconcile(
    reconcileRequest(),
    reconcileDeps(supabase, {
      google: googleFor(undefined, {
        subscription: async (token: string) => {
          if (token.startsWith("before-") || token.startsWith("after-")) {
            throw new GooglePlayApiError(400, "invalidToken", "invalidToken");
          }
          return baseSubscription({
            externalAccountIdentifiers: undefined,
            acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED",
          });
        },
      }),
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    ok: true,
    processed: 1,
    failed: 8,
    skipped: 0,
    acknowledged: 0,
  });
});

Deno.test("resolveBoundUser prioritizes matching direct IDs and searches tokens in order without crossing users", async () => {
  const direct = await resolveBoundUser({
    externalAccountIdentifiers: { obfuscatedExternalAccountId: "user-1" },
    purchaseToken: "current",
  }, "user-1");
  assertEquals(direct, { userId: "user-1", via: "externalAccountIdentifiers" });

  const supabase = new MockSupabase();
  supabase.lookupByToken["expired"] = { user_id: "user-1" };
  const found = await resolveBoundUser(
    {
      externalAccountIdentifiers: { obfuscatedExternalAccountId: "other-user" },
      outOfAppPurchaseContext: { expiredPurchaseToken: "expired" },
      linkedPurchaseToken: "linked",
    },
    "user-1",
    supabase,
  );
  assertEquals(found, {
    userId: "user-1",
    via: "play_purchases:outOfAppPurchaseContext.expiredPurchaseToken",
  });
  assertEquals(supabase.queryCalls.length, 1);

  const noJwt = await resolveBoundUser({
    outOfAppPurchaseContext: {
      expiredExternalAccountIdentifiers: {
        obfuscatedExternalAccountId: "restored-user",
      },
    },
  });
  assertEquals(noJwt.userId, "restored-user");
  assertEquals(
    noJwt.via,
    "outOfAppPurchaseContext.expiredExternalAccountIdentifiers",
  );
});

Deno.test("resolveBoundUser resolves both direct identifier routes for the matching JWT", async () => {
  const externalId = await resolveBoundUser({
    externalAccountIdentifiers: { obfuscatedExternalAccountId: "user-1" },
  }, "user-1");
  assertEquals(externalId, {
    userId: "user-1",
    via: "externalAccountIdentifiers",
  });

  const expiredExternalId = await resolveBoundUser({
    outOfAppPurchaseContext: {
      expiredExternalAccountIdentifiers: {
        obfuscatedExternalAccountId: "user-1",
      },
    },
  }, "user-1");
  assertEquals(expiredExternalId, {
    userId: "user-1",
    via: "outOfAppPurchaseContext.expiredExternalAccountIdentifiers",
  });
});

Deno.test("resolveBoundUser resolves each purchase-token lookup route", async () => {
  const routes = [
    {
      playSub: { purchaseToken: "current-token" },
      matchedToken: "current-token",
      via: "play_purchases:purchaseToken",
      queried: ["current-token"],
    },
    {
      playSub: {
        purchaseToken: "current-token",
        outOfAppPurchaseContext: { expiredPurchaseToken: "expired-token" },
      },
      matchedToken: "expired-token",
      via: "play_purchases:outOfAppPurchaseContext.expiredPurchaseToken",
      queried: ["current-token", "expired-token"],
    },
    {
      playSub: {
        purchaseToken: "current-token",
        outOfAppPurchaseContext: { expiredPurchaseToken: "expired-token" },
        linkedPurchaseToken: "linked-token",
      },
      matchedToken: "linked-token",
      via: "play_purchases:linkedPurchaseToken",
      queried: ["current-token", "expired-token", "linked-token"],
    },
  ];

  for (const route of routes) {
    const supabase = new MockSupabase();
    supabase.lookupByToken[route.matchedToken] = { user_id: "user-1" };
    const result = await resolveBoundUser(route.playSub, "user-1", supabase);
    assertEquals(result, { userId: "user-1", via: route.via });
    assertEquals(
      supabase.queryCalls.map((query) =>
        query.filters.find(([column]) => column === "purchase_token")?.[1]
      ),
      route.queried,
    );
  }
});

Deno.test("resolveBoundUser returns no match and rejects direct or stored IDs differing from the JWT", async () => {
  const directMismatch = await resolveBoundUser({
    externalAccountIdentifiers: { obfuscatedExternalAccountId: "other-user" },
  }, "user-1");
  assertEquals(directMismatch, { userId: null, via: null });

  const supabase = new MockSupabase();
  supabase.lookupByToken["current-token"] = { user_id: "other-user" };
  const storedMismatch = await resolveBoundUser(
    {
      purchaseToken: "current-token",
    },
    "user-1",
    supabase,
  );
  assertEquals(storedMismatch, { userId: null, via: null });

  const notFound = await resolveBoundUser(
    {
      purchaseToken: "missing-token",
      outOfAppPurchaseContext: { expiredPurchaseToken: "also-missing" },
    },
    null,
    new MockSupabase(),
  );
  assertEquals(notFound, { userId: null, via: null });
});
