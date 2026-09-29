import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../state/providers.dart';

/// Slides a slim "You're offline" strip in above the whole app whenever the
/// device loses its connection. Sits in `MaterialApp.builder`, so it covers
/// every screen without each one knowing about it.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(onlineProvider).value == false;
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: offline
              ? Material(
                  color: AppColors.black,
                  child: SafeArea(
                    bottom: false,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.onPrimary),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              "You're offline — some things won't load or save",
                              style: TextStyle(color: AppColors.onPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        // While the banner is up it already covers the status bar, so the
        // screen below must not pad for it a second time.
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: offline, child: child),
        ),
      ],
    );
  }
}
