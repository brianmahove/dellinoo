import type { Env } from './types';
import { AuthError, verifyFirebaseIdToken } from './auth';
import { getAccessToken, getOrder, computeAmount, patchFields, appendPaidAndPatch } from './firestore';
import { initiateRedirect, initiateExpress, parseForm, verifyHash } from './paynow';

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
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

  let body: { orderId?: string; phone?: string };
  try {
    body = (await request.json()) as { orderId?: string; phone?: string };
  } catch {
    return json({ ok: false, error: 'bad_request', message: 'Invalid JSON body' }, 400);
  }
  const orderId = body.orderId;
  if (!orderId) return json({ ok: false, error: 'bad_request', message: 'orderId is required' }, 400);

  const token = await getAccessToken(env);
  const order = await getOrder(orderId, env, token);
  if (!order) return json({ ok: false, error: 'not_found', message: 'Order not found' }, 404);
  if (order.userId !== uid) return json({ ok: false, error: 'forbidden', message: 'Not your order' }, 403);

  if (order.history.some((e) => e.status === 'paid')) {
    return json({ ok: true, alreadyPaid: true });
  }
  if (order.history.at(-1)?.status !== 'placed') {
    return json({ ok: false, error: 'invalid_state', message: 'This order is not awaiting payment' }, 409);
  }

  // Never trust a client-sent amount, method or phone default — recompute
  // and re-derive everything from the order doc itself.
  const amount = computeAmount(order);
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

  try {
    if (order.payment === 'card') {
      const result = await initiateRedirect(shared);
      if (!result.browserurl) {
        return json({ ok: false, error: 'paynow_error', message: result.error ?? 'Paynow could not start this payment' }, 502);
      }
      if (result.pollurl) await patchFields(orderId, env, token, { paynowPollUrl: result.pollurl });
      return json({ ok: true, flow: 'redirect', redirectUrl: result.browserurl });
    }

    if (order.payment !== 'ecocash' && order.payment !== 'onemoney' && order.payment !== 'innbucks') {
      return json({ ok: false, error: 'invalid_state', message: 'Unknown payment method on this order' }, 409);
    }

    const phone = order.payment === 'innbucks' ? undefined : body.phone || order.address.phone;
    const result = await initiateExpress({ ...shared, phone, method: order.payment });
    if (result.status?.toLowerCase() === 'error') {
      return json({ ok: false, error: 'paynow_error', message: result.error ?? 'Paynow could not start this payment' }, 502);
    }
    if (result.pollurl) await patchFields(orderId, env, token, { paynowPollUrl: result.pollurl });
    return json({
      ok: true,
      flow: 'express',
      authorizationCode: result.authorizationcode,
      authorizationExpires: result.authorizationexpires,
    });
  } catch (err) {
    return json({ ok: false, error: 'paynow_error', message: err instanceof Error ? err.message : 'Payment initiation failed' }, 502);
  }
}

async function handleWebhook(request: Request, env: Env): Promise<Response> {
  // Paynow's resulturl target: no auth (public by nature), secured only by
  // hash validation. Always return 200 — a non-2xx just makes Paynow retry
  // a request that will never validate.
  const text = await request.text();
  const { entries, obj } = parseForm(text);

  if (!(await verifyHash(entries, env.PAYNOW_INTEGRATION_KEY))) {
    console.error('Paynow webhook: hash mismatch for reference', obj.reference);
    return new Response('OK');
  }
  if (obj.status !== 'Paid') return new Response('OK');

  const orderId = obj.reference;
  if (!orderId) return new Response('OK');

  try {
    // Belt-and-suspenders per Paynow's own guidance: re-poll rather than
    // trust the webhook body's status alone.
    if (obj.pollurl) {
      const pollRes = await fetch(obj.pollurl);
      const { entries: pollEntries, obj: pollObj } = parseForm(await pollRes.text());
      const pollValid = await verifyHash(pollEntries, env.PAYNOW_INTEGRATION_KEY);
      if (!pollValid || pollObj.status !== 'Paid') return new Response('OK');
    }

    const token = await getAccessToken(env);
    const order = await getOrder(orderId, env, token);
    if (!order || order.history.some((e) => e.status === 'paid')) return new Response('OK');

    await appendPaidAndPatch(orderId, env, token, obj.paynowreference ?? '');
  } catch (err) {
    console.error('Paynow webhook processing failed', err);
  }
  return new Response('OK');
}
