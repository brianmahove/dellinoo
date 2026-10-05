import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass_dialog.dart';
import 'photos.dart';
import 'theme.dart';

/// Lets the admin pick the part of [photo] to keep: drag inside the box to
/// move it, drag a corner to resize. "Auto-trim" finds the product and cuts
/// away the empty background around it (supplier photos often have a lot).
/// Returns the area as fractions 0..1 of the photo, or null if cancelled /
/// unchanged. The crop itself happens in photos.dart's [cropPhoto].
Future<Rect?> showPhotoCropper(BuildContext context, ProductPhoto photo) async {
  final aspect = (await analyzePhoto(photo.thumb))?.aspect ?? 1;
  if (!context.mounted) return null;
  final area = await showGlassDialog<Rect>(
    context: context,
    builder: (context) => _Cropper(photo: photo, aspect: aspect),
  );
  if (area == null || area == _full) return null;
  return area;
}

const _full = Rect.fromLTWH(0, 0, 1, 1);
const _minSide = 0.08; // of the photo, so the box can't collapse
const _handle = 22.0; // touch size of a corner handle, in pixels

enum _Drag { move, topLeft, topRight, bottomLeft, bottomRight }

class _Cropper extends StatefulWidget {
  const _Cropper({required this.photo, required this.aspect});

  final ProductPhoto photo;
  final double aspect; // photo width / height

  @override
  State<_Cropper> createState() => _CropperState();
}

class _CropperState extends State<_Cropper> {
  Rect _area = _full;
  bool _square = false;
  bool _trimming = false;
  String? _note;
  _Drag? _drag;

  /// Display size of the photo: fits a 380×380 box.
  Size get _view {
    const max = 380.0;
    return widget.aspect >= 1 ? Size(max, max / widget.aspect) : Size(max * widget.aspect, max);
  }

  Rect _px(Rect r) =>
      Rect.fromLTRB(r.left * _view.width, r.top * _view.height, r.right * _view.width, r.bottom * _view.height);

  void _setSquare(bool on) {
    setState(() {
      _square = on;
      if (on) _area = _squareAround(_area.center, math.min(_px(_area).width, _px(_area).height));
    });
  }

  /// A square (in pixels) of side [side] centred on [c], kept inside the photo.
  Rect _squareAround(Offset c, double side) {
    side = math.min(side, math.min(_view.width, _view.height));
    final w = side / _view.width;
    final h = side / _view.height;
    final left = (c.dx - w / 2).clamp(0.0, 1 - w);
    final top = (c.dy - h / 2).clamp(0.0, 1 - h);
    return Rect.fromLTWH(left, top, w, h);
  }

  Future<void> _autoTrim() async {
    setState(() {
      _trimming = true;
      _note = null;
    });
    try {
      final bounds = await photoContentBounds(widget.photo.thumb);
      if (!mounted) return;
      setState(() {
        if (bounds == null) {
          _note = 'No empty background to trim — the product fills the photo.';
        } else {
          _area = _square ? _squareAround(bounds.center, math.max(_px(bounds).width, _px(bounds).height)) : bounds;
        }
      });
    } finally {
      if (mounted) setState(() => _trimming = false);
    }
  }

  void _onPanStart(DragStartDetails d) {
    final r = _px(_area);
    final p = d.localPosition;
    bool near(Offset corner) => (p - corner).distance <= _handle;
    _drag = near(r.topLeft)
        ? _Drag.topLeft
        : near(r.topRight)
        ? _Drag.topRight
        : near(r.bottomLeft)
        ? _Drag.bottomLeft
        : near(r.bottomRight)
        ? _Drag.bottomRight
        : r.contains(p)
        ? _Drag.move
        : null;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final drag = _drag;
    if (drag == null) return;
    final dx = d.delta.dx / _view.width;
    final dy = d.delta.dy / _view.height;
    setState(() {
      var r = _area;
      if (drag == _Drag.move) {
        final left = (r.left + dx).clamp(0.0, 1 - r.width);
        final top = (r.top + dy).clamp(0.0, 1 - r.height);
        _area = Rect.fromLTWH(left, top, r.width, r.height);
        return;
      }
      var left = r.left, top = r.top, right = r.right, bottom = r.bottom;
      if (drag == _Drag.topLeft || drag == _Drag.bottomLeft) left = (left + dx).clamp(0.0, right - _minSide);
      if (drag == _Drag.topRight || drag == _Drag.bottomRight) right = (right + dx).clamp(left + _minSide, 1.0);
      if (drag == _Drag.topLeft || drag == _Drag.topRight) top = (top + dy).clamp(0.0, bottom - _minSide);
      if (drag == _Drag.bottomLeft || drag == _Drag.bottomRight) bottom = (bottom + dy).clamp(top + _minSide, 1.0);
      r = Rect.fromLTRB(left, top, right, bottom);
      if (_square) {
        // Keep the corner opposite the dragged one fixed; side = the smaller.
        final px = _px(r);
        final side = math.min(px.width, px.height);
        final w = side / _view.width;
        final h = side / _view.height;
        r = switch (drag) {
          _Drag.topLeft => Rect.fromLTRB(r.right - w, r.bottom - h, r.right, r.bottom),
          _Drag.topRight => Rect.fromLTRB(r.left, r.bottom - h, r.left + w, r.bottom),
          _Drag.bottomLeft => Rect.fromLTRB(r.right - w, r.top, r.right, r.top + h),
          _ => Rect.fromLTRB(r.left, r.top, r.left + w, r.top + h),
        };
      }
      _area = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return GlassAlertDialog(
      title: const Text('Crop photo'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Drag the box to move it, drag a corner to resize. Auto-trim cuts away empty background '
              'around the product.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox.fromSize(
                size: view,
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    onPanStart: _onPanStart,
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: (_) => _drag = null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(widget.photo.url, fit: BoxFit.fill),
                        CustomPaint(painter: _CropPainter(_px(_area))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_trimming) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(label: const Text('Free'), selected: !_square, onSelected: (_) => _setSquare(false)),
                ChoiceChip(label: const Text('Square'), selected: _square, onSelected: (_) => _setSquare(true)),
                ActionChip(
                  avatar: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Auto-trim'),
                  onPressed: _trimming ? null : _autoTrim,
                ),
                ActionChip(
                  avatar: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset'),
                  onPressed: () => setState(() {
                    _area = _square ? _squareAround(const Offset(0.5, 0.5), double.infinity) : _full;
                    _note = null;
                  }),
                ),
              ],
            ),
            if (_note != null) ...[
              const SizedBox(height: 8),
              Text(_note!, style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _area), child: const Text('Crop')),
      ],
    );
  }
}

/// Dims everything outside [area] and draws its frame, thirds and corners.
class _CropPainter extends CustomPainter {
  _CropPainter(this.area);

  final Rect area;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(area),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(area, line);
    final thin = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      final x = area.left + area.width * i / 3;
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), thin);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), thin);
    }
    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 14.0;
    for (final (c, sx, sy) in [
      (area.topLeft, 1.0, 1.0),
      (area.topRight, -1.0, 1.0),
      (area.bottomLeft, 1.0, -1.0),
      (area.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(c, c + Offset(l * sx, 0), corner);
      canvas.drawLine(c, c + Offset(0, l * sy), corner);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) => old.area != area;
}
