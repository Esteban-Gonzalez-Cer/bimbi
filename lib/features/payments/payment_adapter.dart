import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config.dart';
import '../../core/platform.dart';

abstract interface class PaymentAdapter {
  /// Opens Stripe's PaymentSheet for a test pass and asks the server to verify
  /// it. Returns a short status message; access changes only on the server.
  Future<String> checkout(String plan);

  /// Re-checks unfinished test payments with the server, e.g. one completed
  /// just before the app closed. Returns a short status message.
  Future<String> restore();
}

class StripeTestPayments implements PaymentAdapter {
  // Persist before making the request: process death must not create a new attempt.
  final SharedPreferencesAsync _attempts = SharedPreferencesAsync();
  Future<Map<String, dynamic>> _post(
    String route,
    Map<String, String> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw const CapabilityFailure(
        'auth',
        'Sign in with a verified email before testing payments.',
      );
    }
    final base = Uri.tryParse(AppConfig.paymentBaseUrl);
    if (base == null || base.scheme != 'https' || base.host.isEmpty) {
      throw const CapabilityFailure(
        'configuration',
        'Configure an HTTPS test payment endpoint.',
      );
    }
    final response = await http
        .post(
          Uri.parse('${AppConfig.paymentBaseUrl}/$route'),
          headers: {
            'Authorization': 'Bearer ${await user.getIdToken()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      String? code;
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) {
          code = body['error'] as String;
        }
      } on FormatException {
        code = null;
      }
      throw CapabilityFailure(
        code ?? 'backend',
        code == 'higher_plan_active'
            ? 'Premium is already active, and it includes everything in Plus.'
            : 'The payment server rejected the request. No paid access was granted.',
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<String> checkout(String plan) async {
    if (!AppConfig.stripeKey.startsWith('pk_test_')) {
      throw const CapabilityFailure(
        'configuration',
        'A Stripe test publishable key is required.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw const CapabilityFailure('auth', 'Sign in before testing payments.');
    }
    final attempt = 'payment_attempt:$uid:$plan';
    final key =
        await _attempts.getString(attempt) ??
        List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    await _attempts.setString(attempt, key);
    final intent = await _post('createPaymentIntent', {
      'plan': plan,
      'requestId': key,
    });
    Stripe.publishableKey = AppConfig.stripeKey;
    await Stripe.instance.applySettings();
    if (intent['status'] != 'succeeded') {
      try {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: intent['clientSecret'] as String,
            merchantDisplayName: 'Bimbi — TEST',
            allowsDelayedPaymentMethods: false,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      } on StripeException catch (e) {
        return e.error.code == FailureCode.Canceled
            ? 'Payment cancelled. No paid access granted.'
            : 'Payment declined or interrupted. Retry uses the same test payment.';
      }
    }
    final verified = await _post('verifyPaymentIntent', {
      'paymentIntentId': intent['id'] as String,
    });
    if (verified['verified'] == true) {
      await _attempts.remove(attempt);
      return '${plan == 'premium' ? 'Premium' : 'Plus'} is active for 30 days. '
          'Test payment verified by the server.';
    }
    return 'Payment is not verified. No paid access granted.';
  }

  @override
  Future<String> restore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw const CapabilityFailure('auth', 'Sign in to restore purchases.');
    }
    var restored = 0;
    for (final plan in const ['plus', 'premium']) {
      final attempt = 'payment_attempt:$uid:$plan';
      final key = await _attempts.getString(attempt);
      if (key == null) continue;
      try {
        // The same request id returns the same PaymentIntent; nothing is charged.
        final intent = await _post('createPaymentIntent', {
          'plan': plan,
          'requestId': key,
        });
        if (intent['status'] != 'succeeded') continue;
        final verified = await _post('verifyPaymentIntent', {
          'paymentIntentId': intent['id'] as String,
        });
        if (verified['verified'] == true) {
          restored++;
          await _attempts.remove(attempt);
        }
      } on CapabilityFailure catch (e) {
        if (const {
          'higher_plan_active',
          'attempt_expired',
          'attempt_conflict',
        }.contains(e.code)) {
          await _attempts.remove(attempt);
        } else {
          rethrow;
        }
      }
    }
    return restored == 0
        ? 'Your plan is up to date.'
        : 'Restored a verified test payment.';
  }
}

final paymentAdapterProvider = Provider<PaymentAdapter>(
  (ref) => StripeTestPayments(),
);
