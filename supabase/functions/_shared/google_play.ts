import { importPKCS8, SignJWT } from "https://deno.land/x/jose@v4.14.4/index.ts";

export interface GoogleServiceAccount {
  type?: string;
  client_email: string;
  private_key: string;
}

export class ServiceAccountConfigError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "ServiceAccountConfigError";
    this.code = code;
  }
}

export class GooglePlayApiError extends Error {
  status: number;
  reason: string | null;
  sanitizedBody: string;

  constructor(status: number, reason: string | null, sanitizedBody: string) {
    const message = reason
      ? `Google Play API error (${status}): ${reason}`
      : `Google Play API error (${status})`;
    super(message);
    this.name = "GooglePlayApiError";
    this.status = status;
    this.reason = reason;
    this.sanitizedBody = sanitizedBody;
  }
}

export function maskToken(token?: string | null): string {
  if (!token) return "<none>";
  return token.length > 8 ? `${token.slice(0, 8)}...` : token;
}

function redactSensitiveBody(bodyText: string): string {
  if (!bodyText) return "<empty response>";

  const redacted = bodyText
    .replace(/("(?:purchaseToken|purchase_token|token)"\s*:\s*")([^"]+)(")/gi, '$1[REDACTED]$3')
    .replace(/((?:purchaseToken|purchase_token|token)=)([A-Za-z0-9._~-]+)/gi, '$1[REDACTED]');

  return redacted;
}

export function sanitizeGooglePlayError(bodyText: string): string {
  if (!bodyText) return "<empty response>";

  const safeText = redactSensitiveBody(bodyText);

  try {
    const parsed = JSON.parse(safeText);
    const reason =
      parsed?.error?.errors?.[0]?.reason ??
      parsed?.error?.details?.[0]?.reason ??
      parsed?.error?.status ??
      null;

    if (reason) {
      return String(reason);
    }

    const jsonText = JSON.stringify(parsed);
    return jsonText.length > 800 ? `${jsonText.slice(0, 800)}…` : jsonText;
  } catch {
    const normalized = safeText.replace(/\s+/g, " ").trim();
    return normalized.length > 800 ? `${normalized.slice(0, 800)}…` : normalized;
  }
}

export function parseGooglePlayApiError(status: number, bodyText: string): GooglePlayApiError {
  const sanitized = sanitizeGooglePlayError(bodyText);
  let reason: string | null = null;

  try {
    const parsed = JSON.parse(bodyText);
    reason =
      parsed?.error?.errors?.[0]?.reason ??
      parsed?.error?.details?.[0]?.reason ??
      parsed?.error?.status ??
      null;
  } catch {
    // ignore parse failures and keep the sanitized body string
  }

  return new GooglePlayApiError(status, reason ?? sanitized, sanitized);
}

export function parseServiceAccountInput(rawInput: string): GoogleServiceAccount {
  if (!rawInput || !rawInput.trim()) {
    throw new ServiceAccountConfigError(
      "server_config_missing",
      "Google Service Account configuration is missing"
    );
  }

  let str = rawInput.trim();
  if (!str.startsWith("{")) {
    try {
      str = atob(str);
    } catch {
      throw new ServiceAccountConfigError(
        "server_config_json",
        "Failed to decode Base64 Google Service Account secret"
      );
    }
  }

  let parsed: any;
  try {
    parsed = JSON.parse(str);
  } catch {
    throw new ServiceAccountConfigError(
      "server_config_json",
      "Failed to parse Google Service Account JSON"
    );
  }

  if (
    !parsed ||
    typeof parsed !== "object" ||
    typeof parsed.client_email !== "string" ||
    typeof parsed.private_key !== "string" ||
    !parsed.client_email ||
    !parsed.private_key
  ) {
    throw new ServiceAccountConfigError(
      "server_config_json",
      "Google Service Account JSON is missing client_email or private_key"
    );
  }

  return {
    type: parsed.type,
    client_email: parsed.client_email,
    private_key: parsed.private_key.replace(/\\n/g, "\n"),
  };
}

export function resolveServiceAccountEnv(env: Record<string, string | undefined>): GoogleServiceAccount {
  const b64 = env.GOOGLE_SERVICE_ACCOUNT_JSON_B64;
  if (b64 && b64.trim()) {
    return parseServiceAccountInput(b64);
  }

  const json = env.GOOGLE_SERVICE_ACCOUNT_JSON;
  if (json && json.trim()) {
    return parseServiceAccountInput(json);
  }

  throw new ServiceAccountConfigError(
    "server_config_missing",
    "Missing GOOGLE_SERVICE_ACCOUNT_JSON or GOOGLE_SERVICE_ACCOUNT_JSON_B64 environment variable"
  );
}

let cachedAccessToken: { token: string; email: string; expiresAt: number } | null = null;

export async function getGoogleAccessToken(serviceAccountJsonOrEnv: string | Record<string, string | undefined> | GoogleServiceAccount): Promise<string> {
  let sa: GoogleServiceAccount;

  if (typeof serviceAccountJsonOrEnv === "string") {
    sa = parseServiceAccountInput(serviceAccountJsonOrEnv);
  } else if (
    typeof serviceAccountJsonOrEnv === "object" &&
    serviceAccountJsonOrEnv !== null &&
    typeof (serviceAccountJsonOrEnv as any).client_email === "string" &&
    typeof (serviceAccountJsonOrEnv as any).private_key === "string"
  ) {
    const saObj = serviceAccountJsonOrEnv as GoogleServiceAccount;
    sa = {
      type: saObj.type,
      client_email: saObj.client_email,
      private_key: saObj.private_key.replace(/\\n/g, "\n"),
    };
  } else {
    sa = resolveServiceAccountEnv(serviceAccountJsonOrEnv as Record<string, string | undefined>);
  }

  const nowSec = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > nowSec + 60 && cachedAccessToken.email === sa.client_email) {
    return cachedAccessToken.token;
  }

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
    email: sa.client_email,
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
    throw parseGooglePlayApiError(res.status, body);
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

  throw parseGooglePlayApiError(res.status, body);
}
