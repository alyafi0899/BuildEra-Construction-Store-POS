export function mapSubscriptionState(state?: string): string {
  switch (state) {
    case "SUBSCRIPTION_STATE_ACTIVE":
      return "active";
    case "SUBSCRIPTION_STATE_IN_GRACE_PERIOD":
      return "grace";
    case "SUBSCRIPTION_STATE_CANCELED":
      return "canceled";
    case "SUBSCRIPTION_STATE_ON_HOLD":
      return "on_hold";
    case "SUBSCRIPTION_STATE_PAUSED":
      return "paused";
    case "SUBSCRIPTION_STATE_EXPIRED":
      return "expired";
    default:
      return "none";
  }
}

export function detectTrial(playSub: any): boolean {
  if (playSub?.is_trial === true) return true;
  const lineItem = playSub?.lineItems?.[0];
  if (!lineItem) return false;

  const offerDetails = lineItem.offerDetails;
  if (offerDetails) {
    if (offerDetails.offerStage === "FREE_TRIAL" || offerDetails.offerPhase === "freeTrialPhase") {
      return true;
    }
    if (Array.isArray(offerDetails.offerTags) && offerDetails.offerTags.includes("free-trial")) {
      return true;
    }
  }
  return false;
}

export function extractAmount(playSub: any): number {
  const lineItem = playSub?.lineItems?.[0];
  if (!lineItem) return 0;

  const recurringPrice = lineItem.autoRenewingPlan?.recurringPrice;
  if (recurringPrice) {
    const units = parseInt(recurringPrice.units || "0", 10);
    const nanos = parseInt(recurringPrice.nanos || "0", 10);
    return units + nanos / 1e9;
  }

  return 0;
}

export function normalizePlan(productId?: string): string {
  if (productId && productId.includes("yearly")) {
    return "yearly";
  }
  return "monthly";
}

/**
 * Constant-time string comparison to prevent timing attacks on secret tokens
 */
export function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}
