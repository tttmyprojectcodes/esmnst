import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

// Platform-specific imports
import '../razorpay_web.dart'
    if (dart.library.io) '../razorpay_mobile.dart'
    if (dart.library.js) '../razorpay_web.dart'
    as razorpay;

class RazorpayService {
  static dynamic _razorpay;
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    
    try {
      // Web uses JS interop, Mobile uses Flutter plugin
      if (kIsWeb) {
        // Web - will be initialized when opening
        _razorpay = null;
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile - use razorpay_flutter
        _razorpay = razorpay.Razorpay();
      }
      _isInitialized = true;
      print('✅ Razorpay initialized for ${kIsWeb ? "Web" : Platform.operatingSystem}');
    } catch (e) {
      print('❌ Razorpay init error: $e');
    }
  }

  static Future<void> openPayment({
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
  }) async {
    try {
      initialize();
      
      final prefill = {
        'contact': userPhone,
        'email': userEmail,
      };

      final options = {
        'key': key,
        'amount': amount * 100, // Convert to paise/cents
        'currency': currency,
        'name': name,
        'description': description,
        'order_id': orderId,
        'prefill': prefill,
        'theme': {'color': '#F59E0B'},
      };

      if (kIsWeb) {
        // WEB: Use JS Razorpay
        await _openWebRazorpay(
          options: options,
          onSuccess: onSuccess,
          onError: onError,
          onExternalWallet: onExternalWallet,
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        // MOBILE: Use flutter plugin
        await _openMobileRazorpay(
          options: options,
          onSuccess: onSuccess,
          onError: onError,
          onExternalWallet: onExternalWallet,
        );
      } else {
        throw Exception('Razorpay not supported on this platform');
      }
    } catch (e) {
      print('❌ Razorpay open error: $e');
      onError({'error': {'description': e.toString()}});
    }
  }

  static Future<void> _openWebRazorpay({
    required Map<String, dynamic> options,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(Map<String, dynamic>) onError,
    required Function(Map<String, dynamic>) onExternalWallet,
  }) async {
    try {
      // Create Razorpay instance for Web
      final razorpayInstance = razorpay.Razorpay(options);
      
      // Setup handlers
      // Web uses callback functions
      final successHandler = allowInterop((response) {
        print('✅ Web Payment Success: $response');
        onSuccess(response as Map<String, dynamic>);
      });
      
      final errorHandler = allowInterop((error) {
        print('❌ Web Payment Error: $error');
        onError(error as Map<String, dynamic>);
      });
      
      final externalWalletHandler = allowInterop((response) {
        print('💳 Web External Wallet: $response');
        onExternalWallet(response as Map<String, dynamic>);
      });
      
      // Open Razorpay
      razorpayInstance.open();
    } catch (e) {
      print('❌ Web Razorpay error: $e');
      onError({'error': {'description': e.toString()}});
    }
  }

  static Future<void> _openMobileRazorpay({
    required Map<String, dynamic> options,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(Map<String, dynamic>) onError,
    required Function(Map<String, dynamic>) onExternalWallet,
  }) async {
    try {
      if (_razorpay == null) {
        throw Exception('Razorpay not initialized');
      }

      // Setup event listeners for mobile
      _razorpay.on(razorpay.Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
        print('✅ Mobile Payment Success: $response');
        onSuccess(response);
      });

      _razorpay.on(razorpay.Razorpay.EVENT_PAYMENT_ERROR, (response) {
        print('❌ Mobile Payment Error: $response');
        onError(response);
      });

      _razorpay.on(razorpay.Razorpay.EVENT_EXTERNAL_WALLET, (response) {
        print('💳 Mobile External Wallet: $response');
        onExternalWallet(response);
      });

      // Open Razorpay
      _razorpay.open(options);
    } catch (e) {
      print('❌ Mobile Razorpay error: $e');
      onError({'error': {'description': e.toString()}});
    }
  }

  static void dispose() {
    try {
      if (_razorpay != null && !kIsWeb) {
        _razorpay.clear(); // Clear listeners on mobile
      }
    } catch (e) {
      print('Dispose error: $e');
    }
  }
}

// Helper for Web callbacks
import 'dart:js_util' as js_util;
import 'dart:js' as js;

Function allowInterop(Function f) {
  return js_util.allowInterop(f);
}
