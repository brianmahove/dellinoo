import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/payments.dart';
import 'models.dart';

/// All payment-flow logging goes through this name so it's easy to filter
/// out of `flutter logs`/logcat noise, e.g. `adb logcat | grep payments`.
const _logName = 'payments';

/// How the customer needs to complete payment once initiated.
enum PaynowFlow { redirect, express }

/// Result of asking the payments Worker to initiate a Paynow transaction for
/// an order — see payments/src/index.ts's `POST /paynow/initiate`.
class PaynowInitiateResult {
  const PaynowInitiateResult({
    required this.ok,
    this.alreadyPaid = false,
    this.flow,
    this.redirectUrl,
    this.authorizationCode,
    this.authorizationExpires,
    this.error,
    this.message,
  });

  final bool ok;
  final bool alreadyPaid;
  final PaynowFlow? flow;

  /// Card only: Paynow's hosted payment page to open externally.
  final String? redirectUrl;

  /// InnBucks only: the code the customer enters in their InnBucks app.
  final String? authorizationCode;
  final String? authorizationExpires;

  final String? error;
  final String? message;

  factory PaynowInitiateResult.fromJson(Map<String, dynamic> json) => PaynowInitiateResult(
    ok: json['ok'] as bool? ?? false,
    alreadyPaid: json['alreadyPaid'] as bool? ?? false,
    flow: switch (json['flow']) {
      'redirect' => PaynowFlow.redirect,
      'express' => PaynowFlow.express,
      _ => null,
    },
    redirectUrl: json['redirectUrl'] as String?,
    authorizationCode: json['authorizationCode'] as String?,
    authorizationExpires: json['authorizationExpires'] as String?,
    error: json['error'] as String?,
    message: json['message'] as String?,
  );
}

/// Talks to the `payments/` Cloudflare Worker, which holds Paynow's secret
/// Integration Key and is the only thing allowed to mark an order `paid`
/// (see firestore.rules) — this app never talks to Paynow directly.
///
/// [method] is sent explicitly rather than left for the Worker to infer from
/// the order doc, so a customer can retry with a different payment method
/// than the one chosen at checkout (e.g. EcoCash didn't go through, try
/// InnBucks instead) — see lib/widgets/payment_dialog.dart's retryPayment().
Future<PaynowInitiateResult> initiatePaynowPayment({
  required String orderId,
  required PaymentMethod method,
  String? phone,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Must be signed in to pay.');
  final token = await user.getIdToken();

  developer.log('POST /paynow/initiate orderId=$orderId method=${method.name} phone=${phone != null}', name: _logName);
  http.Response response;
  try {
    response = await http.post(
      Uri.parse('$kPaymentsWorkerUrl/paynow/initiate'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'orderId': orderId,
        'method': method.name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
  } catch (err, stack) {
    // Network-level failure (no response at all) — the Worker/Paynow may
    // still be mid-flight server-side; the order stays `placed` either way,
    // and the Firestore listener in PaymentWaitDialog will still catch a
    // late `paid` webhook even if this call itself never came back.
    developer.log('initiate request failed to reach the Worker', name: _logName, error: err, stackTrace: stack);
    rethrow;
  }

  developer.log('/paynow/initiate -> HTTP ${response.statusCode}: ${response.body}', name: _logName);
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return PaynowInitiateResult.fromJson(body);
}
