import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/push.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'state/providers.dart';
import 'widgets/glass.dart';
import 'widgets/motion.dart';
import 'widgets/offline_banner.dart';

/// The web OAuth client Firebase generated for this project (from
/// `google-services.json`'s `oauth_client` entry) — required by `google_sign_in`
/// on Android even though the app itself is Android-only.
const _googleServerClientId = '239128341649-61jkt6to40lt318r8cbc6rrh8t3u24mv.apps.googleusercontent.com';

Future<void> main() async {
  runZonedGuarded(_main, (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
}

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Debug builds report to Crashlytics too but as noisy dev-session noise —
  // opt out so the console only shows crashes from real installs.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Must be called exactly once, before any other GoogleSignIn method.
  await GoogleSignIn.instance.initialize(serverClientId: _googleServerClientId);
  // Iconly fonts are vendored (not a package), so add their licence by hand.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Iconly'], await rootBundle.loadString('assets/fonts/ICONLY_LICENSE'));
  });
  final prefs = await SharedPreferences.getInstance();
  await Push.init(promos: prefs.getBool(DealsAlertsNotifier.prefsKey) ?? true);
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
    Push.onOrderUpdate = () => ref.read(ordersProvider.notifier).refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Push.onOrderUpdate = null;
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
    // Settings toggles kept as plain statics (like AppColors.dark) so widgets
    // deep in the tree don't each need a ref; the MaterialApp key below
    // remounts the tree when one changes, exactly like a theme switch.
    final glass = ref.watch(glassEffectsProvider);
    final slowMotion = ref.watch(reduceMotionProvider);
    GlassBox.enabled = glass;
    kForceReduceMotion = slowMotion;

    return ThemeReveal(
      key: themeRevealKey,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        // Keyed by mode: switching remounts the widget tree so every screen picks
        // up the new AppColors. Navigation (GoRouter) and app state (Riverpod)
        // live outside this tree, so the user stays where they were.
        child: MaterialApp.router(
          key: ValueKey('$dark-$glass-$slowMotion'),
          title: 'Dellinoo',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          routerConfig: appRouter,
          builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
