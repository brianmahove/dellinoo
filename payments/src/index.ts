import type { Env } from './types';
import { AuthError, verifyFirebaseIdToken, verifyFirebaseIdTokenClaims } from './auth';
import {
  AmountError,
  getAccessToken,
  getOrder,
  getDocFields,
  computeAmount,
  patchFields,
  appendPaidAndPatch,
} from './firestore';
import { orderStatusMessage, sendToUser } from './fcm';
import { initiateRedirect, initiateExpress, parseForm, verifyHash } from './paynow';

function json(data: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json', ...headers } });
}

// The admin panel is a web app on another origin, so /notify/* needs CORS.
// The customer app is native (no CORS) and Paynow calls server-to-server.
const ADMIN_ORIGINS = ['https://dellinoo-admin.web.app', 'https://dellinoo-admin.firebaseapp.com'];

function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') ?? '';
  const allowed = ADMIN_ORIGINS.includes(origin) || /^http:\/\/localhost:\d+$/.test(origin);
  if (!allowed) return {};
  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

const RETURN_PAGE = `<!doctype html><html><body style="font-family:sans-serif;text-align:center;padding:48px 16px">
<h1>Payment received</h1><p>You can switch back to the Dellinoo app now.</p></body></html>`;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response('ok');
    }
    if (request.method === 'GET' && url.pathname === '/paynow/return') {
      return new Response(RETURN_PAGE, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
    }
    if (request.method === 'POST' && url.pathname === '/paynow/initiate') {
      return handleInitiate(request, env, url.origin);
    }
    if (request.method === 'POST' && url.pathname === '/paynow/webhook') {
      return handleWebhook(request, env);
    }
    if (request.method === 'OPTIONS' && url.pathname.startsWith('/notify/')) {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }
    if (request.method === 'POST' && url.pathname === '/notify/order-status') {
      return handleNotifyOrderStatus(request, env);
    }
    return new Response('Not found', { status: 404 });
  },
};

async function handleInitiate(request: Request, env: Env, origin: string): Promise<Response> {
  let uid: string;
  try {
    uid = await verifyFirebaseIdToken(request, env);
  } catch (err) {
    return json({ ok: false, error: 'unauthorized', message: err instanceof AuthError ? err.message : 'Unauthorized' }, 401);
  }

  let body: { orderId?: string; method?: string; phone?: string };
  try {
    body = (await request.json()) as { orderId?: string; method?: string; phone?: string };
  } catch {
    return json({ ok: false, error: 'bad_request', message: 'Invalid JSON body' }, 400);
  }
  const orderId = body.orderId;
  if (!orderId) return json({ ok: false, error: 'bad_request', message: 'orderId is required' }, 400);
  console.log(`initiate: uid=${uid} orderId=${orderId}`);

  // The customer may retry with a different method than the one chosen at
  // checkout (e.g. EcoCash didn't go through, try InnBucks instead) — see
  // lib/widgets/payment_dialog.dart's retryPayment(). This is safe to trust
  // from the client: it only picks which Paynow rail to use, not the amount
  // (always server-recomputed below) or which order/customer it applies to
  // (already verified above). OneMoney isn't in this list — it isn't
  // enabled on the Paynow integration yet.
  const allowedMethods = ['ecocash', 'innbucks', 'card'] as const;
  type AllowedMethod = (typeof allowedMethods)[number];
  const isAllowedMethod = (m: string | undefined): m is AllowedMethod =>
    !!m && (allowedMethods as readonly string[]).includes(m);
  if (body.method !== undefined && !isAllowedMethod(body.method)) {
    return json({ ok: false, error: 'bad_request', message: `Unsupported payment method: ${body.method}` }, 400);
  }

  const token = await getAccessToken(env);
  const order = await getOrder(orderId, env, token);
  if (!order) {
    console.log(`initiate: order ${orderId} not found`);
    return json({ ok: false, error: 'not_found', message: 'Order not found' }, 404);
  }
  if (order.userId !== uid) {
    console.log(`initiate: order ${orderId} belongs to ${order.userId}, not caller ${uid}`);
    return json({ ok: false, error: 'forbidden', message: 'Not your order' }, 403);
  }
  console.log(`initiate: order ${orderId} payment=${order.payment} lastStatus=${order.history.at(-1)?.status}`);

  if (order.history.some((e) => e.status === 'paid')) {
    console.log(`initiate: order ${orderId} already paid, skipping Paynow call`);
    return json({ ok: true, alreadyPaid: true });
  }
  if (order.history.at(-1)?.status !== 'placed') {
    return json({ ok: false, error: 'invalid_state', message: 'This order is not awaiting payment' }, 409);
  }

  const method: AllowedMethod = isAllowedMethod(body.method) ? body.method : (order.payment as AllowedMethod);
  if (!isAllowedMethod(method)) {
    return json({ ok: false, error: 'invalid_state', message: `Unsupported payment method: ${order.payment}` }, 409);
  }

  // Never trust a client-sent amount, order ownership or phone default —
  // recompute/re-derive those from the order doc itself. `method` is the
  // one thing we DO take from the client (validated above).
  let amount: string;
  try {
    amount = await computeAmount(orderId, order, env, token);
  } catch (e) {
    if (e instanceof AmountError) return json({ ok: false, error: e.code, message: e.message }, 409);
    throw e;
  }
  const authemail = order.customerEmail || 'orders@dellinoo.co.zw';
  const resulturl = `${origin}/paynow/webhook`;
  const returnurl = `${origin}/paynow/return?order=${orderId}`;
  const shared = {
    integrationId: env.PAYNOW_INTEGRATION_ID,
    integrationKey: env.PAYNOW_INTEGRATION_KEY,
    reference: orderId,
    amount,
    additionalinfo: `Dellinoo order ${order.displayId}`,
    returnurl,
    resulturl,
    authemail,
  };
  // Keep the order doc's `payment` field in sync with what's actually being
  // attempted, e.g. after a retry picked a different method than checkout.
  const patch: Record<string, string> = method === order.payment ? {} : { payment: method };

  try {
    if (method === 'card') {
      console.log(`initiate: order ${orderId} amount=${amount} -> Paynow initiatetransaction (card)`);
      const result = await initiateRedirect(shared);
      console.log(`initiate: order ${orderId} Paynow responded status=${result.status} browserurl=${!!result.browserurl}`);
      if (!result.browserurl) {
        return json({ ok: false, error: 'paynow_error', message: result.error ?? 'Paynow could not start this payment' }, 502);
      }
      if (result.pollurl) patch.paynowPollUrl = result.pollurl;
      if (Object.keys(patch).length > 0) await patchFields(orderId, env, token, patch);
      return json({ ok: true, flow: 'redirect', redirectUrl: result.browserurl });
    }

    const phone = method === 'innbucks' ? undefined : body.phone || order.address.phone;
    console.log(`initiate: order ${orderId} amount=${amount} -> Paynow remotetransaction (${method})`);
    const result = await initiateExpress({ ...shared, phone, method });
    console.log(`initiate: order ${orderId} Paynow responded status=${result.status} error=${result.error ?? '-'}`);
    if (result.status?.toLowerCase() === 'error') {
      return json({ ok: false, error: 'paynow_error', message: result.error ?? 'Paynow could not start this payment' }, 502);
    }
    if (result.pollurl) patch.paynowPollUrl = result.pollurl;
    if (Object.keys(patch).length > 0) await patchFields(orderId, env, token, patch);
    return json({
      ok: true,
      flow: 'express',
      authorizationCode: result.authorizationcode,
      authorizationExpires: result.authorizationexpires,
    });
  } catch (err) {
    // A throw here can happen AFTER Paynow already accepted the transaction
    // (e.g. our own patchFields call failing) — Paynow may still charge the
    // customer and later call /paynow/webhook successfully even though this
    // response is an error. Check for a webhook log with the same orderId
    // before assuming the payment itself failed.
    console.error(`initiate: order ${orderId} threw`, err);
    return json({ ok: false, error: 'paynow_error', message: err instanceof Error ? err.message : 'Payment initiation failed' }, 502);
  }
}

async function handleWebhook(request: Request, env: Env): Promise<Response> {
  // Paynow's resulturl target: no auth (public by nature), secured only by
  // hash validation. Always return 200 — a non-2xx just makes Paynow retry
  // a request that will never validate.
  const text = await request.text();
  const { entries, obj } = parseForm(text);
  console.log(`webhook: received reference=${obj.reference} status=${obj.status}`);

  if (!(await verifyHash(entries, env.PAYNOW_INTEGRATION_KEY))) {
    console.error(`webhook: hash mismatch for reference=${obj.reference}`);
    return new Response('OK');
  }
  if (obj.status !== 'Paid') {
    console.log(`webhook: reference=${obj.reference} status=${obj.status} is not "Paid", ignoring`);
    return new Response('OK');
  }

  const orderId = obj.reference;
  if (!orderId) return new Response('OK');

  try {
    // Belt-and-suspenders per Paynow's own guidance: re-poll rather than
    // trust the webhook body's status alone.
    if (obj.pollurl) {
      const pollRes = await fetch(obj.pollurl);
      const { entries: pollEntries, obj: pollObj } = parseForm(await pollRes.text());
      const pollValid = await verifyHash(pollEntries, env.PAYNOW_INTEGRATION_KEY);
      console.log(`webhook: order ${orderId} re-poll status=${pollObj.status} hashValid=${pollValid}`);
      if (!pollValid || pollObj.status !== 'Paid') return new Response('OK');
    }

    const token = await getAccessToken(env);
    const order = await getOrder(orderId, env, token);
    if (!order) {
      console.error(`webhook: order ${orderId} not found — dropping a confirmed Paynow payment!`);
      return new Response('OK');
    }
    if (order.history.some((e) => e.status === 'paid')) {
      console.log(`webhook: order ${orderId} already marked paid, skipping duplicate write`);
      return new Response('OK');
    }

    await appendPaidAndPatch(orderId, env, token, obj.paynowreference ?? '');
    console.log(`webhook: order ${orderId} marked paid`);

    // Best effort: the payment is already recorded, so a push failure must
    // never surface as a webhook error.
    try {
      const message = orderStatusMessage('paid', order.displayId);
      if (message) {
        const sent = await sendToUser(order.userId, message, env, token);
        console.log(`webhook: order ${orderId} paid push sent to ${sent} device(s)`);
      }
    } catch (err) {
      console.error(`webhook: order ${orderId} paid push failed`, err);
    }
  } catch (err) {
    // This is the dangerous failure mode: Paynow confirmed the customer
    // paid, but we failed to record it. There's no retry here (Paynow will
    // retry undelivered webhooks itself, but a 200 was already about to be
    // returned) — if this ever logs, manually check Paynow's dashboard for
    // this reference and append the `paid` status by hand if it did pay.
    console.error(`webhook: order ${orderId} failed to record payment`, err);
  }
  return new Response('OK');
}

async function handleNotifyOrderStatus(request: Request, env: Env): Promise<Response> {
  // Called by the admin panel right after it appends a status event (see
  // admin/lib/orders_screen.dart). Spark has no Firestore triggers, so this
  // explicit call stands in for an onUpdate Cloud Function. The message is
  // derived from the order doc's own latest status, never from the request,
  // so the endpoint can't be used to push arbitrary text.
  const cors = corsHeaders(request);
  let email: string | undefined;
  try {
    ({ email } = await verifyFirebaseIdTokenClaims(request, env));
  } catch (err) {
    return json({ ok: false, error: 'unauthorized', message: err instanceof AuthError ? err.message : 'Unauthorized' }, 401, cors);
  }

  let body: { orderId?: string };
  try {
    body = (await request.json()) as { orderId?: string };
  } catch {
    return json({ ok: false, error: 'bad_request', message: 'Invalid JSON body' }, 400, cors);
  }
  const orderId = body.orderId;
  if (!orderId) return json({ ok: false, error: 'bad_request', message: 'orderId is required' }, 400, cors);

  const token = await getAccessToken(env);
  // Same allowlist firestore.rules' isAdmin() enforces.
  if (!email || !(await getDocFields(`admins/${email}`, env, token))) {
    return json({ ok: false, error: 'forbidden', message: 'Admins only' }, 403, cors);
  }

  const order = await getOrder(orderId, env, token);
  if (!order) return json({ ok: false, error: 'not_found', message: 'Order not found' }, 404, cors);
  const latest = order.history.at(-1);
  const message = latest && orderStatusMessage(latest.status, order.displayId, latest.note);
  if (!message) return json({ ok: true, sent: 0 }, 200, cors);

  try {
    const sent = await sendToUser(order.userId, message, env, token);
    console.log(`notify: order ${orderId} status=${latest!.status} by ${email} -> ${sent} device(s)`);
    return json({ ok: true, sent }, 200, cors);
  } catch (err) {
    console.error(`notify: order ${orderId} push failed`, err);
    return json({ ok: false, error: 'push_failed', message: err instanceof Error ? err.message : 'Push failed' }, 502, cors);
  }
}
