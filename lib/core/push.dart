import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../widgets/glass.dart';
import 'router.dart';

/// Push notifications (Firebase Cloud Messaging). FCM is free on Spark; the
/// *sending* happens in the payments Worker (payments/src/fcm.ts) — on a
/// Paynow payment and when the admin panel changes an order's status —
/// because Spark has no Cloud Functions to trigger sends from Firestore.
///
/// This side only keeps the signed-in customer's device token in
/// `users/{uid}/fcmTokens/{token}`, subscribes to the `promos` topic, and
/// handles taps: each message carries a
/// `route` (e.g. `/orders/DL10301`) to open.
///
/// Background/terminated notifications are drawn by Android itself (channel
/// `order_updates`, created in MainActivity.kt); in the foreground they show
/// as a glass toast instead.
class Push {
  Push._();

  static FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  static String? _uid;
  static String? _token;
  static String? _pendingRoute;

  /// Set by the app shell to refresh orders when a status update arrives,
  /// so the order screen the customer opens isn't stale.
  static VoidCallback? onOrderUpdate;

  /// Called once from `main()`, after `Firebase.initializeApp`. [promos] is
  /// the saved "Deals & offers" setting (DealsAlertsNotifier).
  static Future<void> init({required bool promos}) async {
    setPromos(promos);
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => openRoute(m.data['route']));
    _messaging.onTokenRefresh.listen((token) {
      _token = token;
      final uid = _uid;
      if (uid != null) unawaited(_save(uid, token));
    });
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (user != null) unawaited(_register(user.uid));
    });
    // App launched by tapping a notification: the splash screen picks this
    // up via [takePendingRoute] once it has routed to Home.
    try {
      final initial = await _messaging.getInitialMessage();
      _pendingRoute = initial?.data['route'];
    } catch (e) {
      // Never let push setup block app startup.
      debugPrint('Push: getInitialMessage failed: $e');
    }
  }

  /// The route from the notification that launched the app, if any. Only
  /// returned once.
  static String? takePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  static Future<void> _register(String uid) async {
    try {
      // Android 13+ shows the system "Allow notifications?" prompt here
      // (Android only asks twice, then stays quiet); older versions grant it.
      await _messaging.requestPermission();
      final token = await _messaging.getToken();
      if (token == null) return;
      _token = token;
      await _save(uid, token);
    } catch (e) {
      // No Play Services, offline, etc. — notifications just won't arrive.
      debugPrint('Push: registration failed: $e');
    }
  }

  static Future<void> _save(String uid, String token) =>
      _tokenDoc(uid, token).set({'platform': 'android', 'updatedAt': FieldValue.serverTimestamp()});

  static DocumentReference<Map<String, dynamic>> _tokenDoc(String uid, String token) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('fcmTokens').doc(token);

  /// Call *before* signing out (the Firestore rules need the session to
  /// delete the doc). Also rotates the device token, so even if the delete
  /// didn't reach the server, the old doc points at a dead token and the
  /// next person to sign in on this phone never gets this customer's pushes.
  static Future<void> unregister() async {
    final uid = _uid, token = _token;
    try {
      if (uid != null && token != null) await _tokenDoc(uid, token).delete();
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Push: unregister failed: $e');
    }
    _token = null;
  }

  static void _onForeground(RemoteMessage message) {
    onOrderUpdate?.call();
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    final notification = message.notification;
    if (context == null || notification == null) return;
    final route = message.data['route'] as String?;
    showGlassToast(
      context,
      [notification.title, notification.body].whereType<String>().join(' · '),
      actionLabel: route == null ? null : 'View',
      onAction: route == null ? null : () => openRoute(route),
      duration: const Duration(seconds: 5),
    );
  }

  /// Tab roots (a StatefulShellRoute branch) are switched to with `go`;
  /// anything else (an order, a product) is pushed on top so back works.
  static const _tabRoutes = {'/home', '/categories', '/cart', '/wishlist', '/profile'};

  static void openRoute(String? route) {
    if (route == null) return;
    onOrderUpdate?.call();
    _tabRoutes.contains(route) ? appRouter.go(route) : appRouter.push(route);
  }

  /// Subscribes this install to (or out of) the `promos` topic the admin
  /// panel's broadcasts go to. Idempotent; best effort.
  static void setPromos(bool on) {
    (on ? _messaging.subscribeToTopic('promos') : _messaging.unsubscribeFromTopic('promos')).catchError((Object e) {
      debugPrint('Push: promos topic update failed: $e');
    });
  }
}
