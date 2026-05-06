import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../config.dart';

class PaymentService {
  static const String _razorpayKey = String.fromEnvironment('RAZORPAY_KEY', defaultValue: '');

  static void initRazorpay() {
    if (_razorpayKey.isEmpty) {
      debugPrint('⚠️ Razorpay key not configured. Set RAZORPAY_KEY env var.');
    }
  }

  static Future<bool> initiateBookingPayment({
    required int bookingId,
    required double amount,
    required String customerEmail,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    if (_razorpayKey.isEmpty) {
      onFailure();
      return false;
    }

    try {
      final razorpay = Razorpay();
      razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) {
        onSuccess();
      });
      razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) {
        onFailure();
      });
      razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) {
        debugPrint('External wallet selected: ${response['wallet_name']}');
      });

      var options = {
        'key': _razorpayKey,
        'amount': (amount * 100).toInt(), // Amount in paise
        'name': 'Shaadi Ghar Hall Booking',
        'description': 'Payment for booking #$bookingId',
        'prefill': {'contact': customerEmail.split('@').first, 'email': customerEmail},
        'external': {
          'wallets': ['paytm']
        }
      };

      razorpay.open(options);
      return true;
    } catch (e) {
      debugPrint('Payment init failed: $e');
      onFailure();
      return false;
    }
  }

static Future<Map<String, dynamic>> verifyPayment(String paymentId, String orderId, String signature) async {
  // Existing Razorpay verify
}
  
  // NEW: JazzCash / EasyPaisa Hosted Payment
  static Future<String?> createPakistanPayment({
    required int bookingId,
    required double amount,
    required String gateway, // 'jazzcash' or 'easypaisa'
    required String customerPhone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payments/create_order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'booking_id': bookingId,
          'amount': amount,
          'gateway': gateway,
          'customer_phone': customerPhone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['payment_url'];
      } else {
        debugPrint('Backend error: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Payment create error: $e');
      return null;
    }
  }

  static Future<bool> launchPakistanPayment(String paymentUrl) async {
    if (await canLaunchUrl(Uri.parse(paymentUrl))) {
      await launchUrl(Uri.parse(paymentUrl), mode: LaunchMode.externalApplication);
      return true;
    }
    debugPrint('Cannot launch payment URL');
    return false;
  }
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'payment_id': paymentId,
          'order_id': orderId,
          'signature': signature,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}

