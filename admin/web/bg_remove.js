// Product-photo helpers for the admin panel, called from Dart (lib/photos.dart).
//
// Background removal runs entirely in the browser — no server, no per-image
// cost. Model: IS-Net "general use" (DIS, Xuebin Qin et al.), Apache-2.0,
// the int8-quantised ONNX export (44 MB, downloaded on first use and then
// cached by the browser). Runtime: onnxruntime-web (MIT), WASM backend.
// Deliberately NOT @imgly/background-removal or Bria's RMBG: those are AGPL /
// non-commercial, and this panel is proprietary.
(function () {
  const ORT_VERSION = '1.30.0';
  const ORT_BASE = `https://cdn.jsdelivr.net/npm/onnxruntime-web@${ORT_VERSION}/dist/`;
  // Pinned to a commit so the file can't change under us.
  const MODEL_URL =
    'https://huggingface.co/SacredNoir/isnet-general-use-onnx/resolve/ff56cb825ee2637d4726f8a739fb7bf1bf4bea04/isnet-general-use-q8.onnx';
  const SIZE = 1024; // the model's fixed input size
  const MAX_SIDE = 2048; // cap the output so huge phone photos don't exhaust memory

  let sessionPromise = null;

  // Hugging Face redirects to a signed CDN URL that changes every time, so
  // the browser's HTTP cache never hits and every visit would re-download
  // 44 MB. Keep our own copy in Cache Storage, keyed by the pinned URL.
  async function modelBytes() {
    let cache = null;
    try {
      cache = await caches.open('dellinoo-bg-model-v1');
      const hit = await cache.match(MODEL_URL);
      if (hit) return new Uint8Array(await hit.arrayBuffer());
    } catch (_) {} // no Cache Storage (e.g. private window): just download
    const res = await fetch(MODEL_URL);
    if (!res.ok) throw new Error(`Couldn't download the background remover (HTTP ${res.status})`);
    if (cache) await cache.put(MODEL_URL, res.clone()).catch(() => {});
    return new Uint8Array(await res.arrayBuffer());
  }

  function loadSession() {
    if (!sessionPromise) {
      sessionPromise = (async () => {
        const [ort, bytes] = await Promise.all([import(`${ORT_BASE}ort.wasm.min.mjs`), modelBytes()]);
        ort.env.wasm.wasmPaths = ORT_BASE;
        const session = await ort.InferenceSession.create(bytes, { executionProviders: ['wasm'] });
        return { ort, session };
      })().catch((e) => {
        sessionPromise = null; // allow a retry after a network failure
        throw e;
      });
    }
    return sessionPromise;
  }

  function canvas(w, h) {
    const c = document.createElement('canvas');
    c.width = w;
    c.height = h;
    return c;
  }

  const hex = (rgb) => '#' + rgb.map((v) => Math.round(v).toString(16).padStart(2, '0')).join('');
  const median = (px) => [0, 1, 2].map((ch) => px.map((p) => p[ch]).sort((a, b) => a - b)[px.length >> 1]);
  const dist = (a, b) => Math.max(Math.abs(a[0] - b[0]), Math.abs(a[1] - b[1]), Math.abs(a[2] - b[2]));
  // A set of pixels is "flat" if almost all of them are close to their median.
  const flat = (px, tolerance = 14) => {
    const m = median(px);
    return px.filter((p) => dist(p, m) <= tolerance).length / px.length >= 0.85 ? m : null;
  };

  async function pixels(blob, maxSide) {
    const bitmap = await createImageBitmap(blob);
    const scale = Math.min(1, maxSide / Math.max(bitmap.width, bitmap.height));
    const w = Math.max(1, Math.round(bitmap.width * scale));
    const h = Math.max(1, Math.round(bitmap.height * scale));
    const ctx = canvas(w, h).getContext('2d', { willReadFrequently: true });
    ctx.drawImage(bitmap, 0, 0, w, h);
    const aspect = bitmap.width / bitmap.height;
    bitmap.close();
    const data = ctx.getImageData(0, 0, w, h).data;
    return { w, h, aspect, at: (x, y) => [data[(y * w + x) * 4], data[(y * w + x) * 4 + 1], data[(y * w + x) * 4 + 2]], data };
  }

  // { transparent, suggestedBg, aspect } for a photo, from a small copy.
  // transparent: any pixel noticeably see-through. suggestedBg: what to put
  // behind the photo in the app so it blends in, in the format the app reads
  // (`photoBgs`): '#rrggbb' for a flat background; 'linear:#from,#to' for a
  // top-to-bottom fade, 'linear@right:…' left-to-right, 'linear@down-right:…'
  // / 'linear@down-left:…' diagonal; 'radial:#centre,#edge' for a vignette
  // (lighter middle, darker corners); null for transparent photos and busy
  // scenes.
  async function analyze(blob) {
    const { w, h, aspect, at, data } = await pixels(blob, 128);
    for (let i = 3; i < data.length; i += 4) if (data[i] < 250) return { transparent: true, suggestedBg: null, aspect };

    const band = (x0, y0, x1, y1) => {
      const out = [];
      for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) out.push(at(x, y));
      return out;
    };
    const top = band(0, 0, w, 2);
    const bottom = band(0, h - 2, w, h);
    const left = band(0, 0, 2, h);
    const right = band(w - 2, 0, w, h);

    // 1. Flat: the whole outer ring is one colour.
    const solid = flat([...top, ...bottom, ...left, ...right]);
    if (solid) return { transparent: false, suggestedBg: hex(solid), aspect };

    // 2. Diagonal fade: two opposite corners differ, the other two sit halfway.
    // Checked before straight fades: a diagonal fade's single edges can look
    // flat enough to pass for one. (A straight fade fails this test.)
    const corner = (x0, y0) => flat(band(x0, y0, x0 + 4, y0 + 4), 10);
    const [tl, tr, bl, br] = [corner(0, 0), corner(w - 4, 0), corner(0, h - 4), corner(w - 4, h - 4)];
    const halfway = (p, q, m) => p && q && m && dist(m, p.map((v, i) => (v + q[i]) / 2)) <= 14;
    if (tl && br && dist(tl, br) > 14 && halfway(tl, br, tr) && halfway(tl, br, bl)) {
      return { transparent: false, suggestedBg: `linear@down-right:${hex(tl)},${hex(br)}`, aspect };
    }
    if (tr && bl && dist(tr, bl) > 14 && halfway(tr, bl, tl) && halfway(tr, bl, br)) {
      return { transparent: false, suggestedBg: `linear@down-left:${hex(tr)},${hex(bl)}`, aspect };
    }
    // 3. Top-to-bottom fade: top and bottom rows each flat but different.
    const t = flat(top);
    const b = flat(bottom);
    if (t && b && dist(t, b) > 14) return { transparent: false, suggestedBg: `linear:${hex(t)},${hex(b)}`, aspect };

    // 3b. Left-to-right fade: same, with the left and right columns.
    const l = flat(left);
    const r = flat(right);
    if (l && r && dist(l, r) > 14) return { transparent: false, suggestedBg: `linear@right:${hex(l)},${hex(r)}`, aspect };

    // 4. Vignette: the middle of each edge is one colour, the corners another.
    const qx = Math.max(1, Math.round(w / 4));
    const qy = Math.max(1, Math.round(h / 4));
    const mids = flat(
      [...band(qx, 0, w - qx, 2), ...band(qx, h - 2, w - qx, h), ...band(0, qy, 2, h - qy), ...band(w - 2, qy, w, h - qy)],
      18,
    );
    const corners = flat([...band(0, 0, 4, 4), ...band(w - 4, 0, w, 4), ...band(0, h - 4, 4, h), ...band(w - 4, h - 4, w, h)], 20);
    if (mids && corners && dist(mids, corners) > 6) {
      return { transparent: false, suggestedBg: `radial:${hex(mids)},${hex(corners)}`, aspect };
    }

    return { transparent: false, suggestedBg: null, aspect };
  }

  // The part of the photo that isn't background, as fractions {x, y, w, h}
  // with a little breathing room — for "Auto-trim" in the cropper. Background
  // = see-through pixels, or pixels close to the edge colour. Null if the
  // whole photo is content (nothing to trim) or there's no clear background.
  async function contentBounds(blob) {
    const { w, h, at, data } = await pixels(blob, 300);
    const alphaAt = (x, y) => data[(y * w + x) * 4 + 3];
    const ring = [];
    for (let x = 0; x < w; x++) ring.push(at(x, 0), at(x, h - 1));
    for (let y = 0; y < h; y++) ring.push(at(0, y), at(w - 1, y));
    const bg = flat(ring, 18);
    let transparentEdge = true;
    for (let x = 0; x < w && transparentEdge; x++) if (alphaAt(x, 0) > 10 || alphaAt(x, h - 1) > 10) transparentEdge = false;
    if (!bg && !transparentEdge) return null;
    const isContent = (x, y) => (transparentEdge ? alphaAt(x, y) > 24 : dist(at(x, y), bg) > 24);
    let x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (!isContent(x, y)) continue;
        if (x < x0) x0 = x;
        if (x > x1) x1 = x;
        if (y < y0) y0 = y;
        if (y > y1) y1 = y;
      }
    }
    if (x1 < 0) return null;
    const pad = 0.04 * Math.max(w, h);
    x0 = Math.max(0, x0 - pad);
    y0 = Math.max(0, y0 - pad);
    x1 = Math.min(w, x1 + 1 + pad);
    y1 = Math.min(h, y1 + 1 + pad);
    return { x: x0 / w, y: y0 / h, w: (x1 - x0) / w, h: (y1 - y0) / h };
  }

  // Crops to the fraction rect at full resolution (capped like
  // removeBackground) and returns a PNG — lossless and keeps transparency;
  // uploadProductPhoto re-encodes it small.
  async function crop(blob, fx, fy, fw, fh) {
    const bitmap = await createImageBitmap(blob);
    const sx = Math.round(fx * bitmap.width);
    const sy = Math.round(fy * bitmap.height);
    const sw = Math.max(1, Math.round(fw * bitmap.width));
    const sh = Math.max(1, Math.round(fh * bitmap.height));
    const scale = Math.min(1, MAX_SIDE / Math.max(sw, sh));
    const out = canvas(Math.round(sw * scale), Math.round(sh * scale));
    const ctx = out.getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(bitmap, sx, sy, sw, sh, 0, 0, out.width, out.height);
    bitmap.close();
    return new Promise((resolve, reject) =>
      out.toBlob((b) => (b ? resolve(b) : reject(new Error('Could not encode the crop'))), 'image/png'),
    );
  }

  // '#rrggbb' at (fx, fy), each 0..1 across the photo — averaged over a few
  // pixels so a click on noise/JPEG artefacts still gets the real colour.
  async function colorAt(blob, fx, fy) {
    const { w, h, at } = await pixels(blob, 400);
    const cx = Math.min(w - 1, Math.max(0, Math.round(fx * (w - 1))));
    const cy = Math.min(h - 1, Math.max(0, Math.round(fy * (h - 1))));
    const px = [];
    for (let y = Math.max(0, cy - 2); y <= Math.min(h - 1, cy + 2); y++) {
      for (let x = Math.max(0, cx - 2); x <= Math.min(w - 1, cx + 2); x++) px.push(at(x, y));
    }
    return hex([0, 1, 2].map((ch) => px.reduce((s, p) => s + p[ch], 0) / px.length));
  }

  // The browser's eyedropper (Chrome/Edge only): '#rrggbb', or null if the
  // admin pressed Esc or the browser doesn't have one.
  function canPickScreenColor() {
    return 'EyeDropper' in window;
  }
  async function pickScreenColor() {
    try {
      return (await new window.EyeDropper().open()).sRGBHex;
    } catch (_) {
      return null;
    }
  }

  // Returns a PNG with the background made transparent.
  async function removeBackground(blob) {
    const { ort, session } = await loadSession();
    const bitmap = await createImageBitmap(blob);

    // Model input: 1024x1024 (stretched, like rembg does), (pixel - 128) / 256.
    const input = canvas(SIZE, SIZE).getContext('2d', { willReadFrequently: true });
    input.drawImage(bitmap, 0, 0, SIZE, SIZE);
    const px = input.getImageData(0, 0, SIZE, SIZE).data;
    const plane = SIZE * SIZE;
    const tensor = new Float32Array(3 * plane);
    for (let i = 0; i < plane; i++) {
      tensor[i] = (px[i * 4] - 128) / 256;
      tensor[plane + i] = (px[i * 4 + 1] - 128) / 256;
      tensor[2 * plane + i] = (px[i * 4 + 2] - 128) / 256;
    }
    const feeds = { [session.inputNames[0]]: new ort.Tensor('float32', tensor, [1, 3, SIZE, SIZE]) };
    const out = (await session.run(feeds))[session.outputNames[0]].data;

    // Saliency -> alpha mask, stretched to 0..1 like rembg, then the bottom
    // 12% / top 6% snapped to fully clear / fully solid — removes faint ghost
    // specks left in the background without hardening real soft edges.
    let min = Infinity;
    let max = -Infinity;
    for (let i = 0; i < out.length; i++) {
      if (out[i] < min) min = out[i];
      if (out[i] > max) max = out[i];
    }
    const range = max - min || 1;
    const maskCanvas = canvas(SIZE, SIZE);
    const maskCtx = maskCanvas.getContext('2d');
    const mask = maskCtx.createImageData(SIZE, SIZE);
    for (let i = 0; i < plane; i++) {
      const a = ((out[i] - min) / range - 0.12) / 0.82;
      mask.data[i * 4 + 3] = Math.round(Math.min(1, Math.max(0, a)) * 255);
    }
    maskCtx.putImageData(mask, 0, 0);

    // Original photo, keeping only where the (smoothly upscaled) mask is opaque.
    const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height));
    const result = canvas(Math.round(bitmap.width * scale), Math.round(bitmap.height * scale));
    const ctx = result.getContext('2d');
    ctx.drawImage(bitmap, 0, 0, result.width, result.height);
    bitmap.close();
    ctx.globalCompositeOperation = 'destination-in';
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(maskCanvas, 0, 0, result.width, result.height);

    return new Promise((resolve, reject) =>
      result.toBlob((b) => (b ? resolve(b) : reject(new Error('Could not encode the result'))), 'image/png'),
    );
  }

  window.dellinooImages = { analyze, colorAt, contentBounds, crop, removeBackground, canPickScreenColor, pickScreenColor };
})();
