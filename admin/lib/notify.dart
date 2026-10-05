import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Same Worker the customer app pays through (its `kPaymentsWorkerUrl`),
/// which also sends push notifications — see payments/src/fcm.ts. Spark has
/// no Cloud Functions, so the panel calls it explicitly. Every /notify/*
/// route checks the caller is in `admins/`.
const _workerUrl = 'https://dellinoo-payments.dellinoo.workers.dev';

/// POSTs [body] to [path] as the signed-in admin; returns the JSON reply.
/// Throws with the Worker's message on any failure.
Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (idToken == null) throw StateError('Not signed in');
  final res = await http.post(
    Uri.parse('$_workerUrl$path'),
    headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  final reply = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 || reply['ok'] != true) {
    throw Exception(reply['message'] ?? 'HTTP ${res.statusCode}');
  }
  return reply;
}

/// Pushes the order's *latest* status to the customer's phone, right after
/// the panel writes it. The Worker builds the message from the order doc
/// itself, not from anything sent here.
///
/// Returns how many of the customer's devices got it (0 = they have none
/// registered, e.g. notifications off or never signed in on the app).
Future<int> notifyOrderStatus(String orderDocId) async {
  final reply = await _post('/notify/order-status', {'orderId': orderDocId});
  return (reply['sent'] as num?)?.toInt() ?? 0;
}

/// Sends a promo push to every install subscribed to "Deals & offers".
/// [productId], if set, is opened when the notification is tapped.
Future<void> sendBroadcast({required String title, required String body, String? productId}) =>
    _post('/notify/broadcast', {'title': title, 'body': body, 'productId': ?productId});

/// Runs the wishlist price-drop check now (it also runs every 6 hours on
/// its own). Returns the Worker's summary: wishlistItems, drops,
/// customersNotified, devicesReached.
Future<Map<String, dynamic>> runPriceDropsNow() => _post('/notify/price-drops', {});
