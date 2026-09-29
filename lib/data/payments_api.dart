import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/payments.dart';

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
Future<PaynowInitiateResult> initiatePaynowPayment({required String orderId, String? phone}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Must be signed in to pay.');
  final token = await user.getIdToken();

  final response = await http.post(
    Uri.parse('$kPaymentsWorkerUrl/paynow/initiate'),
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    body: jsonEncode({'orderId': orderId, if (phone != null && phone.isNotEmpty) 'phone': phone}),
  );

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  return PaynowInitiateResult.fromJson(body);
}
