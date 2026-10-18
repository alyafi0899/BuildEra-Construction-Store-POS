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

export function pickLineItem(playSub: any, productId?: string): any | null {
  const lineItems = Array.isArray(playSub?.lineItems) ? playSub.lineItems : [];
  const productKey = productId ?? playSub?.productId;

  if (productKey) {
    const match = lineItems.find((item: any) => item?.productId === productKey);
    if (match) return match;
  }

  const preferred = lineItems.find((item: any) => typeof item?.latestSuccessfulOrderId === "string" && item.latestSuccessfulOrderId.length > 0);
  if (preferred) return preferred;

  return lineItems[0] ?? null;
}

export function getOrderId(playSub: any, productId?: string): string | null {
  const chosenLineItem = pickLineItem(playSub, productId);
  return chosenLineItem?.latestSuccessfulOrderId ?? playSub?.latestOrderId ?? null;
}

export function detectTrial(playSub: any, productId?: string): boolean {
  const lineItem = pickLineItem(playSub, productId);
  if (!lineItem) return false;

  const offerPhase = lineItem.offerPhase;
  if (!offerPhase) return false;

  if (offerPhase.freeTrial !== undefined && offerPhase.freeTrial !== null) {
    return true;
  }

  return offerPhase.prorationPeriod?.originalOfferPhaseType === "FREE_TRIAL";
}

export function extractAmount(playSub: any, productId?: string): number {
  const lineItem = pickLineItem(playSub, productId);
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
    { token: playSub?.purchaseToken, via: "purchaseToken" },
    { token: playSub?.outOfAppPurchaseContext?.expiredPurchaseToken, via: "outOfAppPurchaseContext.expiredPurchaseToken" },
    { token: playSub?.linkedPurchaseToken, via: "linkedPurchaseToken" },
  ].filter(({ token }) => typeof token === "string" && token.length > 0);

  const directIdCandidates = [
    {
      id: playSub?.externalAccountIdentifiers?.obfuscatedExternalAccountId,
      via: "externalAccountIdentifiers",
    },
    {
      id: playSub?.outOfAppPurchaseContext?.expiredExternalAccountIdentifiers?.obfuscatedExternalAccountId,
      via: "outOfAppPurchaseContext.expiredExternalAccountIdentifiers",
    },
  ].filter(({ id }) => typeof id === "string" && id.length > 0);

  for (const candidate of directIdCandidates) {
    if (!jwtUserId || candidate.id === jwtUserId) {
      return { userId: candidate.id, via: candidate.via };
    }
  }

  if (supabase) {
    for (const candidate of tokenCandidates) {
      const { data, error } = await supabase
        .from("play_purchases")
        .select("user_id")
        .eq("purchase_token", candidate.token)
        .maybeSingle();

      if (error) {
        console.warn(`resolveBoundUser lookup failed for ${candidate.token}:`, error.message ?? error);
      }

      const matchedUserId = data?.user_id as string | undefined;
      if (matchedUserId && (!jwtUserId || matchedUserId === jwtUserId)) {
        return { userId: matchedUserId, via: `play_purchases:${candidate.via}` };
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
