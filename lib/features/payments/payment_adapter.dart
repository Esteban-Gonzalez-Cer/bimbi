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
  Future<String> checkout(String plan);
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
      throw const CapabilityFailure(
        'backend',
        'The payment server rejected the request. No paid access was granted.',
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
      return 'Test payment verified by the server. Production access remains unchanged.';
    }
    return 'Payment is not verified. No paid access granted.';
  }
}

final paymentAdapterProvider = Provider<PaymentAdapter>(
  (ref) => StripeTestPayments(),
);
