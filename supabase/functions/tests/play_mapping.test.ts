import { assertEquals } from "https://deno.land/std@0.168.0/testing/asserts.ts";
import {
  mapSubscriptionState,
  detectTrial,
  extractAmount,
  normalizePlan,
  constantTimeEqual,
} from "../_shared/play_mapping.ts";

Deno.test("mapSubscriptionState converts Google states correctly", () => {
  assertEquals(mapSubscriptionState("SUBSCRIPTION_STATE_ACTIVE"), "active");
  assertEquals(mapSubscriptionState("SUBSCRIPTION_STATE_IN_GRACE_PERIOD"), "grace");
  assertEquals(mapSubscriptionState("SUBSCRIPTION_STATE_CANCELED"), "canceled");
  assertEquals(mapSubscriptionState("SUBSCRIPTION_STATE_EXPIRED"), "expired");
  assertEquals(mapSubscriptionState("UNKNOWN"), "none");
});

Deno.test("detectTrial identifies free trial phases", () => {
  const trialSub = {
    lineItems: [
      {
        offerDetails: {
          offerStage: "FREE_TRIAL",
        },
      },
    ],
  };
  assertEquals(detectTrial(trialSub), true);

  const regularSub = {
    lineItems: [
      {
        offerDetails: {
          offerStage: "REGULAR",
        },
      },
    ],
  };
  assertEquals(detectTrial(regularSub), false);
});

Deno.test("extractAmount parses recurring price units and nanos", () => {
  const priceSub = {
    lineItems: [
      {
        autoRenewingPlan: {
          recurringPrice: {
            units: "100000",
            nanos: 0,
          },
        },
      },
    ],
  };
  assertEquals(extractAmount(priceSub), 100000);
});

Deno.test("constantTimeEqual performs secure string comparison", () => {
  assertEquals(constantTimeEqual("secret_123", "secret_123"), true);
  assertEquals(constantTimeEqual("secret_123", "secret_999"), false);
  assertEquals(constantTimeEqual("secret_123", "short"), false);
});
