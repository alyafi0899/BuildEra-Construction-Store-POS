import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.14.4/index.ts";

export interface GoogleServiceAccount {
  type?: string;
  client_email: string;
  private_key: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

export async function getGoogleAccessToken(serviceAccountJson: string): Promise<string> {
  const nowSec = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > nowSec + 60) {
    return cachedAccessToken.token;
  }

  const sa: GoogleServiceAccount = JSON.parse(serviceAccountJson);
  const privateKey = sa.private_key.replace(/\\n/g, "\n");
  const importedKey = await importPKCS8(privateKey, "RS256");

  const jwt = await new SignJWT({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
  })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuedAt(nowSec)
    .setExpirationTime(nowSec + 3600)
    .sign(importedKey);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Google OAuth token failed (${res.status}): ${errText}`);
  }

  const data = await res.json();
  const token = data.access_token as String;
  const expiresIn = (data.expires_in as number) || 3600;

  cachedAccessToken = {
    token: token.toString(),
    expiresAt: nowSec + expiresIn,
  };

  return token.toString();
}

export async function getSubscriptionV2({
  packageName,
  token,
  accessToken,
}: {
  packageName: string;
  token: string;
  accessToken: string;
}): Promise<any> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
    packageName
  )}/purchases/subscriptionsv2/tokens/${encodeURIComponent(token)}`;

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json",
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Google Play API Error (${res.status}): ${body}`);
  }

  return await res.json();
}

export async function acknowledgeSubscription({
  packageName,
  subscriptionId,
  token,
  accessToken,
}: {
  packageName: string;
  subscriptionId: string;
  token: string;
  accessToken: string;
}): Promise<boolean> {
  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${encodeURIComponent(
    packageName
  )}/purchases/subscriptions/${encodeURIComponent(
    subscriptionId
  )}/tokens/${encodeURIComponent(token)}:acknowledge`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
  });

  if (res.status === 204 || res.status === 200) {
    return true;
  }

  const body = await res.text();
  if (body.includes("already acknowledged") || body.includes("ALREADY_ACKNOWLEDGED")) {
    return true;
  }

  throw new Error(`Acknowledge failed (${res.status}): ${body}`);
}
