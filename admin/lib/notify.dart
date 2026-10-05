import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Same Worker the customer app pays through (its `kPaymentsWorkerUrl`),
/// which also sends push notifications — see payments/src/fcm.ts.
const _workerUrl = 'https://dellinoo-payments.dellinoo.workers.dev';

/// Pushes the order's *latest* status to the customer's phone. Spark has no
/// Cloud Functions to do this from a Firestore trigger, so the panel calls
/// it explicitly right after writing the status. The Worker builds the
/// message from the order doc itself and checks the caller is in `admins/`.
///
/// Returns how many of the customer's devices got it (0 = they have none
/// registered, e.g. notifications off or never signed in on the app).
/// Throws on failure — the status itself is already saved by then.
Future<int> notifyOrderStatus(String orderDocId) async {
  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (idToken == null) throw StateError('Not signed in');
  final res = await http.post(
    Uri.parse('$_workerUrl/notify/order-status'),
    headers: {'Authorization': 'Bearer $idToken', 'Content-Type': 'application/json'},
    body: jsonEncode({'orderId': orderDocId}),
  );
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (res.statusCode != 200 || body['ok'] != true) {
    throw Exception(body['message'] ?? 'HTTP ${res.statusCode}');
  }
  return (body['sent'] as num?)?.toInt() ?? 0;
}
