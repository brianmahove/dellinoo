import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'notify.dart' show workerUrl;

/// Product photos live in Supabase Storage (free tier), not Firebase Storage
/// (needs Blaze). Uploads go through the payments Worker, which checks the
/// caller is an admin and enforces the free-tier limits — see
/// payments/src/images.ts. Photos are shrunk here in the browser first: a
/// full-size copy for the product page and a small one for grids, because
/// Supabase's free tier can't resize on the fly and egress is capped at 5 GB.

const _fullSide = 1200;
const _thumbSide = 400;

/// One product photo: [url] for the product page, [thumb] for grids. Photos
/// pasted as a link (e.g. the demo catalogue) use the same URL for both.
/// [bg] is the colour the customer app shows behind it ('#rrggbb'); null
/// means the app's usual tint.
class ProductPhoto {
  const ProductPhoto(this.url, this.thumb, {this.bg});

  final String url;
  final String thumb;
  final String? bg;

  ProductPhoto withBg(String? bg) => ProductPhoto(url, thumb, bg: bg);

  /// Whether this photo is in our Supabase bucket (so the Worker can delete it).
  bool get isOurs => url.contains('.supabase.co/storage/v1/object/public/');
}

/// Opens the browser's file chooser; returns the picked images (empty if
/// cancelled).
Future<List<web.File>> pickImageFiles({bool multiple = true}) {
  final completer = Completer<List<web.File>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp'
    ..multiple = multiple;
  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      if (completer.isCompleted) return;
      completer.complete([for (var i = 0; i < (files?.length ?? 0); i++) files!.item(i)!]);
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(const []);
    }).toJS,
  );
  input.click();
  return completer.future;
}

/// Shrinks [image] so its longest side is at most [maxSide] (never enlarges)
/// and re-encodes it as WebP, which keeps transparency — or JPEG on browsers
/// that can't encode WebP (Safari), which would otherwise silently fall back
/// to a huge PNG. JPEG has no transparency, so that path gets a white
/// background instead of the black a see-through area would turn into.
Future<Uint8List> _shrink(web.Blob image, int maxSide) async {
  final bitmap = await web.window.createImageBitmap(image).toDart;
  final scale = math.min(1.0, maxSide / math.max(bitmap.width, bitmap.height));
  final w = (bitmap.width * scale).round();
  final h = (bitmap.height * scale).round();
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  final ctx = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(bitmap, 0, 0, w, h);
  bitmap.close();

  var blob = await _toBlob(canvas, 'image/webp', 0.82);
  if (blob == null || blob.type != 'image/webp') {
    final flat = web.HTMLCanvasElement()
      ..width = w
      ..height = h;
    final flatCtx = flat.getContext('2d')! as web.CanvasRenderingContext2D;
    flatCtx.fillStyle = 'white'.toJS;
    flatCtx.fillRect(0, 0, w, h);
    flatCtx.drawImage(canvas, 0, 0);
    blob = await _toBlob(flat, 'image/jpeg', 0.85);
  }
  if (blob == null) throw Exception("This browser couldn't process the photo");
  final buffer = await blob.arrayBuffer().toDart;
  return buffer.toDart.asUint8List();
}

Future<web.Blob?> _toBlob(web.HTMLCanvasElement canvas, String type, double quality) {
  final completer = Completer<web.Blob?>();
  canvas.toBlob(((web.Blob? blob) => completer.complete(blob)).toJS, type, quality.toJS);
  return completer.future;
}

String _ext(Uint8List bytes) => bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8 ? 'jpg' : 'webp';

Future<String> _idToken() async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (token == null) throw StateError('Not signed in');
  return token;
}

/// Shrinks and uploads one product photo (a picked file, or the result of
/// [removeBackgroundFrom]); returns its full and thumb URLs.
Future<ProductPhoto> uploadProductPhoto(web.Blob image) async {
  final full = await _shrink(image, _fullSide);
  final thumb = await _shrink(image, _thumbSide);
  final request = http.MultipartRequest('POST', Uri.parse('$workerUrl/images?kind=product'))
    ..headers['Authorization'] = 'Bearer ${await _idToken()}'
    ..files.add(http.MultipartFile.fromBytes('file', full, filename: 'photo.${_ext(full)}'))
    ..files.add(http.MultipartFile.fromBytes('thumb', thumb, filename: 'thumb.${_ext(thumb)}'));
  final res = await http.Response.fromStream(await request.send());
  final reply = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 || reply['ok'] != true) throw Exception(reply['message'] ?? 'HTTP ${res.statusCode}');
  return ProductPhoto(reply['url'] as String, reply['thumbUrl'] as String);
}

/// Deletes photos from Supabase. Links that aren't ours are skipped. Best
/// effort: a failure only leaves an orphaned file behind, never breaks a save.
Future<void> deletePhotos(Iterable<ProductPhoto> photos) async {
  final urls = {
    for (final p in photos.where((p) => p.isOurs)) ...[p.url, p.thumb],
  }.toList();
  for (var i = 0; i < urls.length; i += 20) {
    try {
      await http.delete(
        Uri.parse('$workerUrl/images'),
        headers: {'Authorization': 'Bearer ${await _idToken()}', 'Content-Type': 'application/json'},
        body: jsonEncode({'urls': urls.sublist(i, math.min(i + 20, urls.length))}),
      );
    } catch (_) {}
  }
}

/// A product doc's photos. `thumbs` and `photoBgs` are parallel to `images`;
/// older products only have one `thumbnail`, so it's derived.
List<ProductPhoto> photosOf(Map<String, dynamic>? d) {
  final images = List<String>.from(d?['images'] as List? ?? const []);
  final thumbs = List<String>.from(d?['thumbs'] as List? ?? const []);
  final bgs = d?['photoBgs'] as List? ?? const [];
  if (images.isEmpty && (d?['thumbnail'] as String? ?? '').isNotEmpty) images.add(d!['thumbnail'] as String);
  return [
    for (var i = 0; i < images.length; i++)
      ProductPhoto(
        images[i],
        i < thumbs.length ? thumbs[i] : (i == 0 ? (d?['thumbnail'] as String? ?? images[i]) : images[i]),
        bg: i < bgs.length ? bgs[i] as String? : null,
      ),
  ];
}

/// web/bg_remove.js — loaded by index.html before Flutter starts.
@JS('dellinooImages')
external _ImageTools get _imageTools;

extension type _ImageTools._(JSObject _) implements JSObject {
  external JSPromise<_Analysis> analyze(web.Blob image);
  external JSPromise<JSString> colorAt(web.Blob image, double fx, double fy);
  external JSPromise<_Bounds?> contentBounds(web.Blob image);
  external JSPromise<web.Blob> crop(web.Blob image, double fx, double fy, double fw, double fh);
  external JSPromise<web.Blob> removeBackground(web.Blob image);
  external bool canPickScreenColor();
  external JSPromise<JSString?> pickScreenColor();
}

extension type _Bounds._(JSObject _) implements JSObject {
  external double get x;
  external double get y;
  external double get w;
  external double get h;
}

extension type _Analysis._(JSObject _) implements JSObject {
  external bool get transparent;
  external String? get suggestedBg;
  external double get aspect;
}

// Thumbs are tiny and never change (immutable names), so keep them for
// repeated checks / colour picks instead of re-downloading on every click.
final _blobs = <String, Future<web.Blob>>{};

Future<web.Blob> _download(String url) => _blobs[url] ??= () async {
  final res = await http.get(Uri.parse(url));
  if (res.statusCode != 200) {
    _blobs.remove(url);
    throw Exception("Couldn't load the photo (HTTP ${res.statusCode})");
  }
  return web.Blob([res.bodyBytes.toJS].toJS);
}();

/// What we know about the photo at [url] (check the small thumb, it's
/// enough): whether it's already see-through; the background to put behind
/// it in the app so it blends in — a `photoBgs` value, see [PhotoBg] — or
/// null for busy backgrounds; and its width/height. Null if it couldn't be
/// checked.
Future<({bool transparent, String? suggestedBg, double aspect})?> analyzePhoto(String url) async {
  try {
    final a = await _imageTools.analyze(await _download(url)).toDart;
    return (transparent: a.transparent, suggestedBg: a.suggestedBg, aspect: a.aspect);
  } catch (_) {
    return null;
  }
}

/// The colour ('#rrggbb') at ([fx], [fy]) — fractions 0..1 across the photo.
Future<String> photoColorAt(String url, double fx, double fy) async =>
    (await _imageTools.colorAt(await _download(url), fx, fy).toDart).toDart;

/// The part of the photo that isn't background (fractions 0..1, with a
/// little margin), for the cropper's Auto-trim; null if there's nothing to trim.
Future<Rect?> photoContentBounds(String url) async {
  final b = await _imageTools.contentBounds(await _download(url)).toDart;
  return b == null ? null : Rect.fromLTWH(b.x, b.y, b.w, b.h);
}

/// Crops the full-size photo at [url] to [area] (fractions 0..1). Returns a
/// PNG, ready for [uploadProductPhoto].
Future<web.Blob> cropPhoto(String url, Rect area) async =>
    _imageTools.crop(await _download(url), area.left, area.top, area.width, area.height).toDart;

/// Whether the browser has an eyedropper (Chrome/Edge do, Firefox/Safari don't).
bool get canPickScreenColor => _imageTools.canPickScreenColor();

/// Lets the admin click anywhere on screen to pick a colour; null if cancelled.
Future<String?> pickScreenColor() async => (await _imageTools.pickScreenColor().toDart)?.toDart;

/// Cuts the background out of the photo at [url] in the browser (the first
/// call downloads a 44 MB model, cached afterwards). Returns a transparent
/// PNG, ready for [uploadProductPhoto].
Future<web.Blob> removeBackgroundFrom(String url) async {
  return _imageTools.removeBackground(await _download(url)).toDart;
}

/// How a photo's background is drawn in the customer app — one entry of a
/// product's `photoBgs`, stored as a string the app parses the same way
/// (lib/data/models.dart `PhotoBg`, kept in sync by hand):
/// `#rrggbb` (flat); `linear:#from,#to` (top→bottom fade) or
/// `linear@<direction>:#from,#to` for the other [FadeDirection]s; or
/// `radial:#centre,#edge` (vignette).
enum PhotoBgStyle { solid, linear, radial }

/// Which way a linear fade runs, from the first colour to the second.
enum FadeDirection {
  down('down', '↓', 'Top', 'Bottom', Alignment.topCenter, Alignment.bottomCenter),
  right('right', '→', 'Left', 'Right', Alignment.centerLeft, Alignment.centerRight),
  downRight('down-right', '↘', 'Top-left', 'Bottom-right', Alignment.topLeft, Alignment.bottomRight),
  downLeft('down-left', '↙', 'Top-right', 'Bottom-left', Alignment.topRight, Alignment.bottomLeft);

  const FadeDirection(this.id, this.arrow, this.fromLabel, this.toLabel, this.begin, this.end);

  final String id;
  final String arrow;
  final String fromLabel;
  final String toLabel;
  final Alignment begin;
  final Alignment end;
}

class PhotoBg {
  const PhotoBg(this.style, this.a, [String? b, this.direction = FadeDirection.down]) : b = b ?? a;

  final PhotoBgStyle style;
  final String a; // the flat colour / fade start / centre
  final String b; // fade end / edge (same as [a] for solid)
  final FadeDirection direction; // linear only

  static final _hex = RegExp(r'^#[0-9a-f]{6}$');
  static final _fade = RegExp(r'^(linear(?:@([a-z-]+))?|radial):(#[0-9a-f]{6}),(#[0-9a-f]{6})$');

  static PhotoBg? parse(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    if (_hex.hasMatch(v)) return PhotoBg(PhotoBgStyle.solid, v);
    final m = _fade.firstMatch(v);
    if (m == null) return null;
    if (m[1] == 'radial') return PhotoBg(PhotoBgStyle.radial, m[3]!, m[4]!);
    final direction = m[2] == null ? FadeDirection.down : FadeDirection.values.where((d) => d.id == m[2]).firstOrNull;
    if (direction == null) return null;
    return PhotoBg(PhotoBgStyle.linear, m[3]!, m[4]!, direction);
  }

  PhotoBg copyWith({PhotoBgStyle? style, String? a, String? b, FadeDirection? direction}) =>
      PhotoBg(style ?? this.style, a ?? this.a, b ?? this.b, direction ?? this.direction);

  /// Labels for the two colours in the picker.
  String get fromLabel => style == PhotoBgStyle.radial ? 'Centre' : direction.fromLabel;
  String get toLabel => style == PhotoBgStyle.radial ? 'Edge' : direction.toLabel;

  @override
  String toString() => switch (style) {
    PhotoBgStyle.solid => a,
    PhotoBgStyle.linear => direction == FadeDirection.down ? 'linear:$a,$b' : 'linear@${direction.id}:$a,$b',
    PhotoBgStyle.radial => 'radial:$a,$b',
  };

  static Color colorOf(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  /// Same drawing as the customer app's `productBackdrop`.
  BoxDecoration decoration({BorderRadius? radius, BoxShape shape = BoxShape.rectangle}) => BoxDecoration(
    shape: shape,
    borderRadius: radius,
    color: style == PhotoBgStyle.solid ? colorOf(a) : null,
    gradient: switch (style) {
      PhotoBgStyle.solid => null,
      PhotoBgStyle.linear => LinearGradient(
        begin: direction.begin,
        end: direction.end,
        colors: [colorOf(a), colorOf(b)],
      ),
      PhotoBgStyle.radial => RadialGradient(radius: 0.9, colors: [colorOf(a), colorOf(b)]),
    },
  );
}
