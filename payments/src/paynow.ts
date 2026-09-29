// Paynow's API: application/x-www-form-urlencoded in both directions, and
// every request/response is signed with SHA-512(values-in-order + Integration
// Key), uppercase hex. See https://developers.paynow.co.zw/docs/generating_hash.html

export interface RedirectInitiateOptions {
  integrationId: string;
  integrationKey: string;
  reference: string;
  amount: string;
  additionalinfo: string;
  returnurl: string;
  resulturl: string;
  authemail: string;
}

export interface ExpressInitiateOptions extends RedirectInitiateOptions {
  phone?: string;
  method: 'ecocash' | 'onemoney' | 'innbucks';
}

export interface PaynowResponse {
  status?: string;
  browserurl?: string;
  pollurl?: string;
  error?: string;
  authorizationcode?: string;
  authorizationexpires?: string;
  paynowreference?: string;
  reference?: string;
  amount?: string;
}

async function sha512Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-512', new TextEncoder().encode(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('').toUpperCase();
}

async function buildSignedForm(pairs: [string, string][], key: string): Promise<string> {
  const hash = await sha512Hex(pairs.map(([, v]) => v).join('') + key);
  const params = new URLSearchParams();
  for (const [k, v] of pairs) params.append(k, v);
  params.append('hash', hash);
  return params.toString();
}

// Parses a Paynow x-www-form-urlencoded body, preserving field order —
// needed to reconstruct the hash exactly as Paynow built it.
export function parseForm(text: string): { entries: [string, string][]; obj: Record<string, string> } {
  const params = new URLSearchParams(text);
  const entries = [...params.entries()];
  const obj: Record<string, string> = {};
  for (const [k, v] of entries) obj[k] = v;
  return { entries, obj };
}

export async function verifyHash(entries: [string, string][], key: string): Promise<boolean> {
  const hashEntry = entries.find(([k]) => k.toLowerCase() === 'hash');
  if (!hashEntry) return false;
  const values = entries.filter(([k]) => k.toLowerCase() !== 'hash').map(([, v]) => v);
  const expected = await sha512Hex(values.join('') + key);
  return expected === hashEntry[1].toUpperCase();
}

async function postAndVerify(url: string, pairs: [string, string][], key: string): Promise<PaynowResponse> {
  const body = await buildSignedForm(pairs, key);
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  const rawText = await res.text();
  const { entries, obj } = parseForm(rawText);

  const hasHash = entries.some(([k]) => k.toLowerCase() === 'hash');
  if (!hasHash) {
    // Paynow's plain validation-error responses (e.g. "not a valid test
    // case number", a malformed field) aren't signed at all — there's
    // nothing to verify, and treating "no hash" the same as "hash present
    // but wrong" hid a perfectly good, actionable error message behind a
    // scary "security failure" one. Only a genuine Error response is safe
    // to trust unsigned (it carries no payment-affecting data); anything
    // else missing a hash is unexpected and stays untrusted.
    if (obj.status?.toLowerCase() === 'error') {
      console.error(`Paynow returned an unsigned error response from ${url}: ${rawText}`);
      return obj;
    }
    console.error(`Paynow response has no hash and isn't a plain error either — ${url}: ${rawText}`);
    throw new Error('Paynow response was missing its security hash');
  }

  if (!(await verifyHash(entries, key))) {
    // Log the raw body before throwing — otherwise this failure is
    // undiagnosable later (was it a duplicate-reference error page, a
    // malformed field, or something else entirely?).
    console.error(`Paynow response hash did not validate for ${url}: ${rawText}`);
    throw new Error('Paynow response hash did not validate');
  }
  return obj;
}

// Card only — the browser-redirect flow. `status` here is the literal
// constant "Message", unrelated to payment state.
export function initiateRedirect(opts: RedirectInitiateOptions): Promise<PaynowResponse> {
  const pairs: [string, string][] = [
    ['id', opts.integrationId],
    ['reference', opts.reference],
    ['amount', opts.amount],
    ['additionalinfo', opts.additionalinfo],
    ['returnurl', opts.returnurl],
    ['resulturl', opts.resulturl],
    ['authemail', opts.authemail],
    ['status', 'Message'],
  ];
  return postAndVerify('https://www.paynow.co.zw/interface/initiatetransaction', pairs, opts.integrationKey);
}

// EcoCash, OneMoney and InnBucks — all "Express Checkout". `phone` is
// omitted entirely for InnBucks (not needed; it returns an authorization
// code instead).
export function initiateExpress(opts: ExpressInitiateOptions): Promise<PaynowResponse> {
  const pairs: [string, string][] = [
    ['id', opts.integrationId],
    ['reference', opts.reference],
    ['amount', opts.amount],
    ['additionalinfo', opts.additionalinfo],
    ['returnurl', opts.returnurl],
    ['resulturl', opts.resulturl],
    ['authemail', opts.authemail],
  ];
  if (opts.phone) pairs.push(['phone', opts.phone]);
  pairs.push(['method', opts.method]);
  pairs.push(['status', 'Message']);
  return postAndVerify('https://www.paynow.co.zw/interface/remotetransaction', pairs, opts.integrationKey);
}
