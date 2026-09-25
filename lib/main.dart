import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'state/providers.dart';
import 'widgets/motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const DellinooApp()));
}

class DellinooApp extends ConsumerStatefulWidget {
  const DellinooApp({super.key});

  @override
  ConsumerState<DellinooApp> createState() => _DellinooAppState();
}

class _DellinooAppState extends ConsumerState<DellinooApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Follow the phone's light/dark setting live when the mode is "System".
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final platformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final dark = mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    AppColors.dark = dark;

    return ThemeReveal(
      key: themeRevealKey,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        // Keyed by mode: switching remounts the widget tree so every screen picks
        // up the new AppColors. Navigation (GoRouter) and app state (Riverpod)
        // live outside this tree, so the user stays where they were.
        child: MaterialApp.router(
          key: ValueKey(dark),
          title: 'Dellinoo',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
