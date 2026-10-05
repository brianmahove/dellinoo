import type { Env } from './types';

// Verifies a Firebase Auth ID token ourselves (no `firebase-admin` — it
// doesn't run on the Workers runtime) against Google's public JWKs, and
// returns the verified `sub` (uid). Never trust a client-supplied uid — this
// is the only source of truth for "who is calling".
export class AuthError extends Error {}

interface Jwk {
  kid: string;
  kty: string;
  n: string;
  e: string;
  [key: string]: unknown;
}

const JWKS_URL = 'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

function base64UrlToUint8Array(input: string): Uint8Array {
  const padded = input.replace(/-/g, '+').replace(/_/g, '/');
  const pad = padded.length % 4 === 0 ? '' : '='.repeat(4 - (padded.length % 4));
  const binary = atob(padded + pad);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function base64UrlDecodeToString(input: string): string {
  return new TextDecoder().decode(base64UrlToUint8Array(input));
}

export async function verifyFirebaseIdToken(request: Request, env: Env): Promise<string> {
  return (await verifyFirebaseIdTokenClaims(request, env)).uid;
}

// Same check, but also returns the verified email — the admin allowlist
// (`admins/{email}`, see ../firestore.rules' isAdmin()) is keyed by it.
export async function verifyFirebaseIdTokenClaims(request: Request, env: Env): Promise<{ uid: string; email?: string }> {
  const authHeader = request.headers.get('Authorization') ?? '';
  const match = /^Bearer (.+)$/.exec(authHeader);
  if (!match) throw new AuthError('Missing bearer token');
  const token = match[1];

  const parts = token.split('.');
  if (parts.length !== 3) throw new AuthError('Malformed token');
  const [headerB64, payloadB64, signatureB64] = parts;

  const header = JSON.parse(base64UrlDecodeToString(headerB64)) as { alg?: string; kid?: string };
  if (header.alg !== 'RS256' || !header.kid) throw new AuthError('Unsupported token header');

  const payload = JSON.parse(base64UrlDecodeToString(payloadB64)) as {
    aud?: string;
    iss?: string;
    exp?: number;
    sub?: string;
    email?: string;
  };

  const now = Math.floor(Date.now() / 1000);
  if (payload.aud !== env.FIREBASE_PROJECT_ID) throw new AuthError('Wrong audience');
  if (payload.iss !== `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}`) throw new AuthError('Wrong issuer');
  if (!payload.exp || payload.exp <= now) throw new AuthError('Token expired');
  if (!payload.sub) throw new AuthError('Missing subject');

  const jwksRes = await fetch(JWKS_URL);
  if (!jwksRes.ok) throw new AuthError('Could not fetch signing keys');
  const { keys } = (await jwksRes.json()) as { keys: Jwk[] };
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new AuthError('Unknown signing key');

  const publicKey = await crypto.subtle.importKey(
    'jwk',
    jwk as unknown as JsonWebKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );

  const signedData = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature = base64UrlToUint8Array(signatureB64);
  const valid = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', publicKey, signature, signedData);
  if (!valid) throw new AuthError('Invalid signature');

  return { uid: payload.sub, email: payload.email };
}
