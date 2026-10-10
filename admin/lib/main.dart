import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs (/orders) instead of the default hash ones (/#/orders). Needs
  // the SPA rewrite on the admin Hosting target (firebase.json), or a reload
  // on any page but the root would 404.
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final _auth = AdminAuth();
  late final _router = buildAdminRouter(_auth);

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dellinoo Admin',
      debugShowCheckedModeBanner: false,
      theme: buildAdminTheme(),
      routerConfig: _router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        if (mq.size.width >= 600) return child!;
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(0.9)),
          child: Theme(
            data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
            child: child!,
          ),
        );
      },
    );
  }
}
