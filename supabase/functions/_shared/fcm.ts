/**
 * Firebase Cloud Messaging HTTP v1 API クライアント。
 *
 * - サービスアカウント JSON で OAuth2 access token を取得（5分キャッシュ）
 * - `sendToToken(token, notification, data)` で1端末に push 送信
 *
 * 環境変数:
 *   FCM_SERVICE_ACCOUNT_JSON : Firebase コンソールから取得した
 *     サービスアカウント JSON 全文（client_email / private_key / project_id を含む）。
 *
 * 設定が無い場合は `sendToToken` は false を返して握りつぶす（push 不能なだけで業務処理は継続）。
 */

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

let cachedSa: ServiceAccount | null | undefined;
let cachedToken: { token: string; expiresAt: number } | null = null;

function loadServiceAccount(): ServiceAccount | null {
  if (cachedSa !== undefined) return cachedSa;
  const raw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    cachedSa = null;
    return null;
  }
  try {
    const parsed = JSON.parse(raw) as ServiceAccount;
    if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
      console.error("[FCM] service account JSON missing required fields");
      cachedSa = null;
      return null;
    }
    cachedSa = parsed;
    return cachedSa;
  } catch (e) {
    console.error("[FCM] failed to parse service account JSON:", e);
    cachedSa = null;
    return null;
  }
}

function b64urlEncode(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let str = "";
  for (let i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
  return btoa(str).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function pemToDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const raw = atob(b64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const copy = new Uint8Array(bytes.byteLength);
  copy.set(bytes);
  return copy.buffer;
}

async function getAccessToken(sa: ServiceAccount): Promise<string | null> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 60_000) {
    return cachedToken.token;
  }

  const nowSec = Math.floor(Date.now() / 1000);
  const header = b64urlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64urlEncode(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: nowSec,
    exp: nowSec + 3600,
  }));
  const signingInput = `${header}.${payload}`;

  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "pkcs8",
      toArrayBuffer(pemToDer(sa.private_key)),
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
  } catch (e) {
    console.error("[FCM] importKey failed:", e);
    return null;
  }

  const sig = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      toArrayBuffer(new TextEncoder().encode(signingInput)),
    ),
  );
  const jwt = `${signingInput}.${b64urlEncode(sig)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!res.ok) {
    const body = await res.text();
    console.error("[FCM] token exchange failed:", res.status, body);
    return null;
  }

  const json = await res.json() as { access_token: string; expires_in: number };
  cachedToken = {
    token: json.access_token,
    expiresAt: Date.now() + json.expires_in * 1000,
  };
  return cachedToken.token;
}

export async function sendToToken(
  token: string,
  notification: { title: string; body: string },
  data: Record<string, string> = {},
): Promise<boolean> {
  const sa = loadServiceAccount();
  if (!sa) return false;
  const accessToken = await getAccessToken(sa);
  if (!accessToken) return false;

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: { token, notification, data },
      }),
    },
  );

  if (!res.ok) {
    const body = await res.text();
    console.error("[FCM] send failed:", res.status, body);
    return false;
  }
  return true;
}
