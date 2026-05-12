// ─────────────────────────────────────────────
//  jazzcash_payment.dart
//  Drop this file in:  lib/features/payment/
//
//  Contains:
//   1. PaymentModel
//   2. JazzCashService  (API calls)
//   3. JazzCashPaymentScreen  (full payment UI)
// ─────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ─── CHANGE THIS to your actual backend URL ───
const String _baseUrl = 'https://hallbooking.pythonanywhere.com';

// =================================================
//  1. PAYMENT MODEL
// =================================================

class PaymentModel {
  final int paymentId;
  final int bookingId;
  final String txnRefNo;
  final double amount;
  final String mobileNumber;
  final String status; // pending | success | failed
  final Map<String, dynamic> jazzcashResponse;
  final String createdAt;
  final String updatedAt;

  const PaymentModel({
    required this.paymentId,
    required this.bookingId,
    required this.txnRefNo,
    required this.amount,
    required this.mobileNumber,
    required this.status,
    required this.jazzcashResponse,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      paymentId: json['payment_id'] as int,
      bookingId: json['booking_id'] as int,
      txnRefNo: json['txn_ref_no'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      mobileNumber: json['mobile_number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      jazzcashResponse:
          json['jazzcash_response'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

// Booking ka payment status response
class BookingPaymentStatus {
  final int bookingId;
  final String paymentStatus; // unpaid | paid | failed | refunded
  final String paymentReference;
  final List<PaymentModel> payments;

  const BookingPaymentStatus({
    required this.bookingId,
    required this.paymentStatus,
    required this.paymentReference,
    required this.payments,
  });

  factory BookingPaymentStatus.fromJson(Map<String, dynamic> json) {
    return BookingPaymentStatus(
      bookingId: json['booking_id'] as int,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentReference: json['payment_reference'] as String? ?? '',
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) => PaymentModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

// =================================================
//  2. SERVICE
// =================================================

class JazzCashService {
  /// JazzCash payment initiate karo
  /// Returns: {'success': bool, 'message': String, 'payment': PaymentModel?}
  static Future<Map<String, dynamic>> initiatePayment({
    required int bookingId,
    required String mobileNumber,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/payments/jazzcash/initiate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'booking_id': bookingId,
              'mobile_number': mobileNumber,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final data = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final paymentData = data['payment'] as Map<String, dynamic>?;
        return {
          'success': true,
          'message': data['message'] ?? 'Payment initiated.',
          'payment':
              paymentData != null ? PaymentModel.fromJson(paymentData) : null,
          'txn_ref_no': data['txn_ref_no'] ?? '',
        };
      } else {
        return {
          'success': false,
          'message':
              data['error'] ?? 'Payment failed. Please try again.',
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Request timed out. Check your internet connection.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Booking ka payment status check karo (polling ke liye)
  static Future<BookingPaymentStatus?> getPaymentStatus(
      int bookingId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/payments/$bookingId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return BookingPaymentStatus.fromJson(
            json.decode(response.body) as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

// =================================================
//  3. JAZZCASH PAYMENT SCREEN
//
//  Usage:
//  Navigator.push(context, MaterialPageRoute(
//    builder: (_) => JazzCashPaymentScreen(
//      bookingId: booking.hallBookingId,
//      totalAmount: booking.totalCost,
//      hallName: booking.hallName,
//      onPaymentSuccess: () {
//        // Navigate to success page or refresh bookings
//      },
//    ),
//  ));
// =================================================

class JazzCashPaymentScreen extends StatefulWidget {
  final int bookingId;
  final double totalAmount;
  final String hallName;
  final VoidCallback? onPaymentSuccess;

  const JazzCashPaymentScreen({
    super.key,
    required this.bookingId,
    required this.totalAmount,
    required this.hallName,
    this.onPaymentSuccess,
  });

  @override
  State<JazzCashPaymentScreen> createState() =>
      _JazzCashPaymentScreenState();
}

class _JazzCashPaymentScreenState extends State<JazzCashPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  // States: idle | loading | polling | success | failed
  String _state = 'idle';
  String _statusMessage = '';
  String _txnRefNo = '';
  Timer? _pollingTimer;
  int _pollCount = 0;
  static const int _maxPolls = 12; // 12 × 5s = 60s max wait

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mobileController.dispose();
    super.dispose();
  }

  // ── Step 1: Initiate ──────────────────────────
  Future<void> _initiatePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _state = 'loading';
      _statusMessage = 'Connecting to JazzCash...';
    });

    final result = await JazzCashService.initiatePayment(
      bookingId: widget.bookingId,
      mobileNumber: _mobileController.text.trim(),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      final payment = result['payment'] as PaymentModel?;
      _txnRefNo = result['txn_ref_no'] as String? ?? '';

      if (payment?.status == 'success') {
        // Sandbox mein turant success milta hai
        _handleSuccess();
      } else {
        // Production mein polling start karo
        setState(() {
          _state = 'polling';
          _statusMessage =
              'Waiting for JazzCash confirmation...\nPlease approve on your JazzCash app.';
        });
        _startPolling();
      }
    } else {
      setState(() {
        _state = 'failed';
        _statusMessage = result['message'] as String;
      });
    }
  }

  // ── Step 2: Poll payment status ───────────────
  void _startPolling() {
    _pollCount = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      _pollCount++;
      final status =
          await JazzCashService.getPaymentStatus(widget.bookingId);

      if (!mounted) {
        _pollingTimer?.cancel();
        return;
      }

      if (status?.paymentStatus == 'paid') {
        _pollingTimer?.cancel();
        _handleSuccess();
        return;
      }

      if (status?.paymentStatus == 'failed' || _pollCount >= _maxPolls) {
        _pollingTimer?.cancel();
        setState(() {
          _state = 'failed';
          _statusMessage = _pollCount >= _maxPolls
              ? 'Payment confirmation timeout.\nPlease check your JazzCash app and try again.'
              : 'Payment was declined by JazzCash.';
        });
      } else {
        setState(() {
          _statusMessage =
              'Checking payment status... ($_pollCount/$_maxPolls)\nPlease approve on your JazzCash app.';
        });
      }
    });
  }

  void _handleSuccess() {
    setState(() {
      _state = 'success';
      _statusMessage = 'Payment successful!';
    });
    widget.onPaymentSuccess?.call();
  }

  void _retry() {
    _pollingTimer?.cancel();
    setState(() {
      _state = 'idle';
      _statusMessage = '';
      _txnRefNo = '';
      _pollCount = 0;
    });
  }

  // ── BUILD ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text(
          'Pay with JazzCash',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildAmountCard(),
              const SizedBox(height: 24),
              if (_state == 'idle' || _state == 'loading')
                _buildForm()
              else if (_state == 'polling')
                _buildPollingState()
              else if (_state == 'success')
                _buildSuccessState()
              else if (_state == 'failed')
                _buildFailedState(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Amount card ───────────────────────────────
  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB6465F), Color(0xFF8B2A3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB6465F).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/jazzcash_logo.png',
                height: 28,
                errorBuilder: (_, __, ___) => const Row(
                  children: [
                    Icon(Icons.payment, color: Colors.white, size: 24),
                    SizedBox(width: 6),
                    Text('JazzCash',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Secure Payment',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.hallName,
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            'PKR ${widget.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Booking #${widget.bookingId}',
            style: TextStyle(
                color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Form (mobile number input) ─────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // How it works
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enter your JazzCash mobile number. You will receive a payment request on your JazzCash app.',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'JazzCash Mobile Number',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        const SizedBox(height: 8),

        Form(
          key: _formKey,
          child: TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 11,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '03001234567',
              prefixIcon: const Icon(Icons.phone_android,
                  color: Color(0xFFB6465F)),
              filled: true,
              fillColor: Colors.white,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFB6465F), width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Mobile number is required.';
              }
              if (val.trim().length < 11) {
                return 'Enter a valid 11-digit mobile number.';
              }
              if (!val.trim().startsWith('03')) {
                return 'Number must start with 03.';
              }
              return null;
            },
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _state == 'loading' ? null : _initiatePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB6465F),
              disabledBackgroundColor:
                  const Color(0xFFB6465F).withOpacity(0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _state == 'loading'
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'Pay Now',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // Security note
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Text(
              'Payments are processed securely by JazzCash',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  // ── Polling state ─────────────────────────────
  Widget _buildPollingState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const SizedBox(
          width: 70,
          height: 70,
          child: CircularProgressIndicator(
            color: Color(0xFFB6465F),
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Awaiting Payment',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        if (_txnRefNo.isNotEmpty)
          Text(
            'Ref: $_txnRefNo',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: _retry,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFB6465F)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFFB6465F)),
          ),
        ),
      ],
    );
  }

  // ── Success state ─────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Successful!',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50)),
        ),
        const SizedBox(height: 10),
        Text(
          'PKR ${widget.totalAmount.toStringAsFixed(0)} paid for ${widget.hallName}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (_txnRefNo.isNotEmpty)
          Text(
            'Transaction Ref: $_txnRefNo',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Back to Booking',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // ── Failed state ──────────────────────────────
  Widget _buildFailedState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.close_rounded, color: Colors.white, size: 52),
        ),
        const SizedBox(height: 20),
        const Text(
          'Payment Failed',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.red),
        ),
        const SizedBox(height: 10),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB6465F),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.grey),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text(
            'Pay Later',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// =================================================
//  HOW TO USE — Booking Detail Screen mein
// =================================================

/*

// Booking confirm hone ke baad "Pay Now" button dikhao:

if (booking.paymentStatus == 'unpaid') ...[
  SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: const Icon(Icons.payment, color: Colors.white),
      label: const Text(
        'Pay with JazzCash',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFB6465F),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JazzCashPaymentScreen(
            bookingId: booking.hallBookingId,
            totalAmount: booking.totalCost,
            hallName: booking.hallName,
            onPaymentSuccess: () {
              // Booking list refresh karo
              setState(() => booking = booking.copyWith(paymentStatus: 'paid'));
            },
          ),
        ),
      ),
    ),
  ),
] else if (booking.paymentStatus == 'paid') ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle, color: Colors.green),
        const SizedBox(width: 8),
        Text('Paid — Ref: ${booking.paymentReference}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
      ],
    ),
  ),
],

*/