import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RazorpayService {
  static void openPayment({
    required double amount,
    required String currency,
    required String orderId,
    required String key,
    required String name,
    required String description,
    required String userEmail,
    required String userPhone,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(Map<String, dynamic>) onError,
    required Function(Map<String, dynamic>) onExternalWallet,
  }) {
    if (kIsWeb) {
      // Web: Use the JS SDK
      try {
        final options = {
          'key': key,
          'amount': amount * 100,
          'currency': currency,
          'name': name,
          'description': description,
          'order_id': orderId,
          'prefill': {
            'contact': userPhone,
            'email': userEmail,
          },
          'theme': {'color': '#F59E0B'},
          'handler': (response) {
            onSuccess(response as Map<String, dynamic>);
          },
          'modal': {
            'ondismiss': () {
              onError({'error': {'description': 'Payment modal closed'}});
            }
          }
        };

        // Call the Razorpay constructor from the JS SDK
        final razorpay = js_util.callConstructor(
          js.context['Razorpay'] as js.JsFunction,
          [js.JsObject.jsify(options)],
        );
        js_util.callMethod(razorpay, 'open', []);
      } catch (e) {
        onError({'error': {'description': 'Failed to open Razorpay: $e'}});
      }
    } else {
      // Mobile: Use the Razorpay Flutter plugin
      try {
        // This is a placeholder - you need to implement mobile logic
        // using the razorpay_flutter package
        onError({'error': {'description': 'Mobile Razorpay not implemented yet'}});
      } catch (e) {
        onError({'error': {'description': 'Mobile Razorpay error: $e'}});
      }
    }
  }
}
