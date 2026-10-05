import type { Env } from './types';
import { getDocFields, incrementFields } from './firestore';

// Image storage on Supabase's free tier, so Firebase can stay on Spark
// (Firebase Storage needs Blaze). The bucket is public-read — the app loads
// photos straight from Supabase by URL — but nothing can write to it except
// this Worker, which holds the Supabase secret key. Every upload is checked
// here first: who's calling, what they may upload, file type and size, and
// the storage cap below, so the free tier's 1 GB can never be exceeded.

// Leaves 200 MB of Supabase's 1 GB as headroom (the counter can drift a
// little, e.g. a crash between upload and increment).
const STORAGE_CAP_BYTES = 800 * 1024 * 1024;
const MAX_ADMIN_FILE_BYTES = 2 * 1024 * 1024;
const MAX_CUSTOMER_FILE_BYTES = 1024 * 1024;
const CUSTOMER_DAILY_FILES = 20;
const MAX_DELETE_URLS = 20;

// Running total of what's in the bucket. Firestore, not Supabase, because
// Supabase's API has no cheap "bucket size" call. No firestore.rules entry:
// clients can't read or write it, only this Worker (service account).
const USAGE_DOC = 'meta/imageStorage';

export type ImageKind = 'product' | 'review' | 'request';
const KINDS: readonly string[] = ['product', 'review', 'request'];

export interface Caller {
  uid: string;
  isAdmin: boolean;
  token: string; // Google access token for Firestore
}

class ImageError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

function json(data: unknown, status: number, cors: Record<string, string>): Response {
  return new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json', ...cors } });
}

// From the file's own bytes, never its name or the client's Content-Type.
function detectType(bytes: Uint8Array): { mime: string; ext: string } | null {
  const b = bytes;
  if (b.length >= 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return { mime: 'image/jpeg', ext: 'jpg' };
  if (b.length >= 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) {
    return { mime: 'image/png', ext: 'png' };
  }
  const ascii = (from: number, to: number) => String.fromCharCode(...b.slice(from, to));
  if (b.length >= 12 && ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') return { mime: 'image/webp', ext: 'webp' };
  return null;
}

function publicPrefix(env: Env): string {
  return `${env.SUPABASE_URL}/storage/v1/object/public/${env.SUPABASE_BUCKET}/`;
}

function supabaseHeaders(env: Env): Record<string, string> {
  // New-style `sb_secret_…` keys and legacy service_role JWTs both work
  // when sent as both headers, which is what supabase-js does too.
  return { apikey: env.SUPABASE_SECRET_KEY, Authorization: `Bearer ${env.SUPABASE_SECRET_KEY}` };
}

async function putObject(env: Env, path: string, bytes: Uint8Array, mime: string): Promise<void> {
  const res = await fetch(`${env.SUPABASE_URL}/storage/v1/object/${env.SUPABASE_BUCKET}/${path}`, {
    method: 'POST',
    headers: {
      ...supabaseHeaders(env),
      'Content-Type': mime,
      // Names are random and never reused, so a photo never changes: let
      // phones and Supabase's CDN keep it for a year (saves egress).
      'cache-control': 'max-age=31536000, immutable',
      'x-upsert': 'false',
    },
    body: bytes,
  });
  if (!res.ok) throw new Error(`Supabase upload ${path} failed: ${res.status} ${await res.text()}`);
}

// Returns the total size of what was actually deleted.
async function deleteObjects(env: Env, paths: string[]): Promise<{ files: number; bytes: number }> {
  const res = await fetch(`${env.SUPABASE_URL}/storage/v1/object/${env.SUPABASE_BUCKET}`, {
    method: 'DELETE',
    headers: { ...supabaseHeaders(env), 'Content-Type': 'application/json' },
    body: JSON.stringify({ prefixes: paths }),
  });
  if (!res.ok) throw new Error(`Supabase delete failed: ${res.status} ${await res.text()}`);
  const deleted = (await res.json()) as Array<{ metadata?: { size?: number } }>;
  return { files: deleted.length, bytes: deleted.reduce((sum, o) => sum + (o.metadata?.size ?? 0), 0) };
}

async function readFile(form: FormData, field: string, maxBytes: number): Promise<{ bytes: Uint8Array; mime: string; ext: string } | null> {
  const entry = form.get(field);
  if (entry === null) return null;
  if (typeof entry === 'string') throw new ImageError(400, 'bad_request', `"${field}" must be a file`);
  if (entry.size > maxBytes) {
    throw new ImageError(413, 'too_large', `"${field}" is over ${Math.round(maxBytes / 1024)} KB — shrink it first`);
  }
  const bytes = new Uint8Array(await entry.arrayBuffer());
  const type = detectType(bytes);
  if (!type) throw new ImageError(415, 'unsupported_type', `"${field}" must be a JPEG, PNG or WebP image`);
  return { bytes, ...type };
}

// POST /images?kind=product|review|request, multipart form with `file` and
// an optional smaller `thumb` (Supabase's free tier can't resize on the fly,
// so the app uploads a grid-sized copy itself). Returns their public URLs.
export async function handleImageUpload(request: Request, env: Env, caller: Caller, cors: Record<string, string>): Promise<Response> {
  try {
    const kind = new URL(request.url).searchParams.get('kind') ?? '';
    if (!KINDS.includes(kind)) throw new ImageError(400, 'bad_request', 'kind must be product, review or request');
    if (kind === 'product' && !caller.isAdmin) throw new ImageError(403, 'forbidden', 'Admins only');

    let form: FormData;
    try {
      form = await request.formData();
    } catch {
      throw new ImageError(400, 'bad_request', 'Expected a multipart form');
    }
    const maxBytes = caller.isAdmin ? MAX_ADMIN_FILE_BYTES : MAX_CUSTOMER_FILE_BYTES;
    const file = await readFile(form, 'file', maxBytes);
    if (!file) throw new ImageError(400, 'bad_request', '"file" is required');
    const thumb = await readFile(form, 'thumb', maxBytes);
    const files = thumb ? [file, thumb] : [file];
    const totalBytes = files.reduce((sum, f) => sum + f.bytes.length, 0);

    if (!caller.isAdmin) {
      const day = new Date().toISOString().slice(0, 10);
      const { count } = await incrementFields(`upload_quota/${caller.uid}_${day}`, env, caller.token, { count: files.length });
      if (count > CUSTOMER_DAILY_FILES) throw new ImageError(429, 'daily_limit', 'Too many photos today, try again tomorrow');
    }

    const usage = await getDocFields(USAGE_DOC, env, caller.token);
    const used = Number(usage?.bytes ?? 0);
    if (used + totalBytes > STORAGE_CAP_BYTES) {
      console.error(`images: storage cap reached (${used} bytes used), refusing upload`);
      throw new ImageError(507, 'storage_full', 'Photo storage is full — ask the admin to remove old photos');
    }

    const folder = kind === 'product' ? 'products' : `${kind}s/${caller.uid}`;
    const id = crypto.randomUUID();
    const filePath = `${folder}/${id}.${file.ext}`;
    const thumbPath = thumb ? `${folder}/${id}_thumb.${thumb.ext}` : undefined;

    await putObject(env, filePath, file.bytes, file.mime);
    if (thumb && thumbPath) await putObject(env, thumbPath, thumb.bytes, thumb.mime);
    await incrementFields(USAGE_DOC, env, caller.token, { bytes: totalBytes, files: files.length });

    console.log(`images: ${kind} upload by ${caller.uid} -> ${filePath} (${totalBytes} bytes)`);
    return json(
      { ok: true, url: publicPrefix(env) + filePath, thumbUrl: thumbPath ? publicPrefix(env) + thumbPath : undefined },
      200,
      cors,
    );
  } catch (err) {
    if (err instanceof ImageError) return json({ ok: false, error: err.code, message: err.message }, err.status, cors);
    console.error('images: upload failed', err);
    return json({ ok: false, error: 'upload_failed', message: 'Upload failed' }, 502, cors);
  }
}

// DELETE /images, JSON { urls: [...] }. Admins may delete anything in the
// bucket; customers only their own review/request photos. URLs that aren't
// ours (e.g. old pasted dummyjson links) are skipped, not an error.
export async function handleImageDelete(request: Request, env: Env, caller: Caller, cors: Record<string, string>): Promise<Response> {
  try {
    let body: { urls?: unknown };
    try {
      body = (await request.json()) as { urls?: unknown };
    } catch {
      throw new ImageError(400, 'bad_request', 'Invalid JSON body');
    }
    if (!Array.isArray(body.urls) || body.urls.length === 0 || body.urls.length > MAX_DELETE_URLS) {
      throw new ImageError(400, 'bad_request', `urls must be a list of 1–${MAX_DELETE_URLS} image URLs`);
    }
    const prefix = publicPrefix(env);
    const own = [`reviews/${caller.uid}/`, `requests/${caller.uid}/`];
    const paths: string[] = [];
    for (const url of body.urls) {
      if (typeof url !== 'string' || !url.startsWith(prefix)) continue;
      const path = url.slice(prefix.length);
      if (path.includes('..')) throw new ImageError(400, 'bad_request', 'Invalid image URL');
      if (!caller.isAdmin && !own.some((p) => path.startsWith(p))) throw new ImageError(403, 'forbidden', 'Not your photo');
      paths.push(path);
    }
    if (paths.length === 0) return json({ ok: true, deleted: 0 }, 200, cors);

    const { files, bytes } = await deleteObjects(env, paths);
    if (files > 0) await incrementFields(USAGE_DOC, env, caller.token, { bytes: -bytes, files: -files });
    console.log(`images: ${caller.uid} deleted ${files} file(s), ${bytes} bytes`);
    return json({ ok: true, deleted: files }, 200, cors);
  } catch (err) {
    if (err instanceof ImageError) return json({ ok: false, error: err.code, message: err.message }, err.status, cors);
    console.error('images: delete failed', err);
    return json({ ok: false, error: 'delete_failed', message: 'Delete failed' }, 502, cors);
  }
}

// Supabase pauses a free project after ~7 days without database activity,
// and a paused project serves no images at all. The cron reads one row of
// the `keepalive` table (see README) every 6 hours so that never happens.
export async function keepSupabaseAwake(env: Env): Promise<void> {
  const res = await fetch(`${env.SUPABASE_URL}/rest/v1/keepalive?select=id&limit=1`, { headers: supabaseHeaders(env) });
  if (!res.ok) throw new Error(`Supabase keep-alive failed: ${res.status} ${await res.text()}`);
  console.log('keepalive: Supabase ok');
}
