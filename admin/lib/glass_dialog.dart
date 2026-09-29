import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Frosted dialogs, ported from the customer app's `lib/widgets/glass.dart`
/// (blurred back screen + translucent rounded panel, like its toasts).
/// Kept in sync by hand, same as `theme.dart`.

ImageFilter _blur(double sigma) => ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

class _GlassDialogRoute<T> extends DialogRoute<T> {
  _GlassDialogRoute({required super.context, required super.builder, super.barrierColor, super.barrierLabel})
    : super(barrierDismissible: true);

  @override
  Widget buildModalBarrier() {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: animation!,
          builder: (_, _) =>
              BackdropFilter(filter: _blur(14 * animation!.value + 0.01), child: const SizedBox.expand()),
        ),
        super.buildModalBarrier(),
      ],
    );
  }
}

/// Drop-in for [showDialog] with a frosted back screen.
Future<T?> showGlassDialog<T>({required BuildContext context, required WidgetBuilder builder}) {
  return Navigator.of(context, rootNavigator: true).push(
    _GlassDialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
}

/// Frosted replacement for [AlertDialog] (`title` / `content` / `actions`).
class GlassAlertDialog extends StatelessWidget {
  const GlassAlertDialog({super.key, this.title, this.content, this.actions = const []});

  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(26);
    return AnimatedPadding(
      padding: MediaQuery.viewInsetsOf(context) + const EdgeInsets.all(24),
      duration: const Duration(milliseconds: 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: BackdropFilter(
                filter: _blur(22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: radius,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: title == null
                                ? null
                                : DefaultTextStyle(
                                    style: (text.titleLarge ?? const TextStyle()).copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 20,
                                    ),
                                    child: title!,
                                  ),
                          ),
                          if (content != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: DefaultTextStyle(
                                style: (text.bodyMedium ?? const TextStyle()).copyWith(
                                  color: AppColors.ink.withValues(alpha: 0.8),
                                  fontSize: 14.5,
                                  height: 1.4,
                                ),
                                child: content!,
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 4, children: actions),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
