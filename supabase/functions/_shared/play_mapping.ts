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
    case "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED":
      return "none";
    default:
      return "none";
  }
}

export function getOrderId(playSub: any): string | null {
  const lineItems = Array.isArray(playSub?.lineItems) ? playSub.lineItems : [];
  const productId = playSub?.productId;
  const matchingLineItem =
    productId != null
      ? lineItems.find((item: any) => item?.productId === productId)
      : undefined;
  const chosenLineItem = matchingLineItem ?? lineItems[0];

  return chosenLineItem?.latestSuccessfulOrderId ?? playSub?.latestOrderId ?? null;
}

export function detectTrial(playSub: any): boolean {
  if (playSub?.is_trial === true) return true;

  const lineItem = playSub?.lineItems?.[0];
  if (!lineItem) return false;

  const offerPhase = lineItem.offerPhase;
  if (offerPhase) {
    if (offerPhase.freeTrial !== undefined) return true;
    if (offerPhase.prorationPeriod?.originalOfferPhaseType === "FREE_TRIAL") {
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

export async function resolveBoundUser(
  playSub: any,
  jwtUserId?: string | null,
  supabase?: { from: (table: string) => any }
): Promise<{ userId: string | null; via: string | null }> {
  const tokenCandidates = [
    playSub?.purchaseToken,
    playSub?.outOfAppPurchaseContext?.expiredPurchaseToken,
    playSub?.linkedPurchaseToken,
  ].filter((token) => typeof token === "string" && token.length > 0);

  const directIdCandidates = [
    playSub?.externalAccountIdentifiers?.obfuscatedExternalAccountId,
    playSub?.outOfAppPurchaseContext?.expiredExternalAccountIdentifiers?.obfuscatedExternalAccountId,
  ].filter((id) => typeof id === "string" && id.length > 0);

  for (const [index, directId] of directIdCandidates.entries()) {
    const via = index === 0 ? "externalAccountIdentifiers" : "expiredExternalAccountIdentifiers";
    if (!jwtUserId || directId === jwtUserId) {
      return { userId: directId, via };
    }
  }

  if (supabase) {
    for (const token of tokenCandidates) {
      const { data, error } = await supabase
        .from("play_purchases")
        .select("user_id")
        .eq("purchase_token", token)
        .maybeSingle();

      if (error) {
        console.warn(`resolveBoundUser lookup failed for ${token}:`, error.message ?? error);
      }

      const matchedUserId = data?.user_id as string | undefined;
      if (matchedUserId && (!jwtUserId || matchedUserId === jwtUserId)) {
        return { userId: matchedUserId, via: `play_purchases:${token}` };
      }
    }
  }

  return { userId: null, via: null };
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
