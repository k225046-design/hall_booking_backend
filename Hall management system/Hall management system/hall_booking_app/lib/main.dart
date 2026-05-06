import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'l10n/app_localizations.dart';
import 'calendar_service.dart';
import 'config.dart';
import 'food_menu_screen.dart';
import 'language_provider.dart';
import 'session_storage.dart';
import 'notification_service.dart';
import 'messages_screen.dart';
import 'message_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: const MyApp(),
    ),
  );
}

Widget buildHomeForRole(String role, Map<String, dynamic> user) {
  switch (role) {
    case 'admin':
      return const AdminDashboard();
    case 'customer':
    case 'client':
      return CustomerDashboard(user: user);
    default:
      return const LandingPage();
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int? userId;
  String? userRole;

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final idStr = await readSessionValue('user_id');
    final role = await readSessionValue('user_role');
    setState(() {
      userId = idStr != null ? int.tryParse(idStr) : null;
      userRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C2D47),
      brightness: Brightness.light,
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Shaadi Ghar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFDADAD6),
        textTheme: GoogleFonts.poppinsTextTheme(),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('ur', ''), // Urdu
      ],
      home: StreamBuilder<List<Message>>(
        stream: NotificationService.messagesStream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.message),
                      SizedBox(width: 8),
                      Expanded(child: Text('New message received!')),
                    ],
                  ),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessagesScreen(
                          userId: userId ?? 1,
                          userRole: userRole ?? 'customer',
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
          }
          return const SessionGate();
        },
      ),
    );
  }
}

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  Future<Map<String, dynamic>?> _loadSession() async {
    final raw = await readSessionValue('session_user');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      await removeSessionValue('session_user');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadSession(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LandingPage();
        }

        final session = snapshot.data!;
        final role = session['role']?.toString() ?? '';
        final user = Map<String, dynamic>.from(session['user'] as Map? ?? {});
        return buildHomeForRole(role, user);
      },
    );
  }
}

class ApiClient {
  const ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
    });
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> payload) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<List<dynamic>> getHalls({
    String query = '',
    String city = '',
    String nearestTo = '',
    String category = '',
    String sortBy = 'featured',
    int? minCapacity,
    int? maxRent,
    bool featured = false,
  }) async {
    final params = <String, String>{};
    if (query.isNotEmpty) params['q'] = query;
    if (city.isNotEmpty) params['city'] = city;
    if (nearestTo.isNotEmpty) params['nearest_to'] = nearestTo;
    if (category.isNotEmpty && category != 'All') params['category'] = category;
    if (sortBy.isNotEmpty) params['sort_by'] = sortBy;
    if (minCapacity != null) params['min_capacity'] = '$minCapacity';
    if (maxRent != null) params['max_rent'] = '$maxRent';
    if (featured) params['featured'] = 'true';

    final uri = Uri.parse('$baseUrl/halls').replace(queryParameters: params);
    return _sendForList(() => http.get(uri));
  }

  Future<Map<String, dynamic>> getAvailability(int hallId) async {
    return _sendForMap(
      () => http.get(Uri.parse('$baseUrl/hall/$hallId/availability')),
    );
  }

  Future<Map<String, dynamic>> getHallFeedback(int hallId) async {
    return _sendForMap(
      () => http.get(Uri.parse('$baseUrl/hall/$hallId/feedback')),
    );
  }

  Future<Map<String, dynamic>> submitHallFeedback(
    int hallId,
    Map<String, dynamic> payload,
  ) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/hall/$hallId/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<Map<String, dynamic>> createBooking(
      Map<String, dynamic> payload) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/book'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<List<dynamic>> getMyBookings(int customerId) async {
    return _sendForList(
      () => http.get(Uri.parse('$baseUrl/customer/bookings/$customerId')),
    );
  }

  // Legacy cancel - replace with new policy-based
  Future<Map<String, dynamic>> cancelBooking(
      int bookingId, int customerId) async {
    return _sendForMap(() {
      return http.put(
        Uri.parse('$baseUrl/customer/cancel_booking/$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customer_id': customerId}),
      );
    });
  }

  // New features
  Future<Map<String, dynamic>> requestCancel(int bookingId, int customerId, String reason) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/booking/$bookingId/request_cancel'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': customerId,
          'reason': reason,
        }),
      );
    });
  }

  Future<Map<String, dynamic>> updateBookingDate(int bookingId, int customerId, String newDate) async {
    return _sendForMap(() {
      return http.put(
        Uri.parse('$baseUrl/booking/$bookingId/update_date'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': customerId,
          'new_date': newDate,
        }),
      );
    });
  }

  Future<Map<String, dynamic>> updateBookingGuests(int bookingId, int customerId, int newGuests) async {
    return _sendForMap(() {
      return http.put(
        Uri.parse('$baseUrl/booking/$bookingId/update_guests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customer_id': customerId,
          'new_guest_count': newGuests,
        }),
      );
    });
  }

  Future<List<dynamic>> getHallMenus(int hallId) async {
    return _sendForList(() => http.get(Uri.parse('$baseUrl/hall/$hallId/menus')));
  }

  Future<Map<String, dynamic>> updateProfile(
      int customerId, Map<String, dynamic> payload) async {
    return _sendForMap(() {
      return http.put(
        Uri.parse('$baseUrl/customer/profile/$customerId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<Map<String, dynamic>> getStats() async {
    return _sendForMap(() => http.get(Uri.parse('$baseUrl/admin/stats')));
  }

  Future<List<dynamic>> getAdminBookings() async {
    return _sendForList(() => http.get(Uri.parse('$baseUrl/admin/bookings')));
  }

  Future<List<dynamic>> getCustomers() async {
    return _sendForList(() => http.get(Uri.parse('$baseUrl/admin/customers')));
  }

  Future<Map<String, dynamic>> updateBookingStatus(
      int bookingId, String status) async {
    return _sendForMap(() {
      return http.put(
        Uri.parse('$baseUrl/admin/update_booking/$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
    });
  }

  Future<Map<String, dynamic>> sendBookingMessage(
    int bookingId,
    String message,
  ) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/admin/send_booking_message/$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': message}),
      );
    });
  }

  Future<Map<String, dynamic>> sendCustomerBookingMessage(
    int bookingId,
    int customerId,
    String message,
  ) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/customer/send_booking_message/$bookingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customer_id': customerId, 'message': message}),
      );
    });
  }

  Future<Map<String, dynamic>> addHall(Map<String, dynamic> payload) async {
    return _sendForMap(() {
      return http.post(
        Uri.parse('$baseUrl/admin/halls'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<Map<String, dynamic>> updateHall(
      int hallId, Map<String, dynamic> payload) async {
    return _sendForMap(() {
      return http.put(
        Uri.parse('$baseUrl/admin/update_hall/$hallId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    });
  }

  Future<void> deleteHall(int hallId) async {
    final response = await _send(
      () => http.delete(Uri.parse('$baseUrl/admin/delete_hall/$hallId')),
    );
    _decode(response);
  }

  Future<Map<String, dynamic>> _sendForMap(
    Future<http.Response> Function() request,
  ) async {
    final response = await _send(request);
    return _decode(response);
  }

  Future<List<dynamic>> _sendForList(
    Future<http.Response> Function() request,
  ) async {
    final response = await _send(request);
    return _decodeList(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(
        'Could not reach the server at $baseUrl. Make sure the Flask backend is running.',
      );
    } on http.ClientException catch (_) {
      throw ApiException(
        'Could not connect to $baseUrl. Check the backend URL and make sure the Flask server is running.',
      );
    } catch (error) {
      final message = error.toString();
      if (message.contains('Failed to fetch') ||
          message.contains('XMLHttpRequest error')) {
        throw ApiException(
          'The app could not reach $baseUrl. Start the Flask backend and verify the client is using the correct host.',
        );
      }
      rethrow;
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final dynamic body = _parseBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (body is Map<String, dynamic>) {
        throw ApiException(body['error']?.toString() ?? 'Request failed.');
      }
      throw ApiException('Request failed.');
    }
    if (body is Map<String, dynamic>) {
      return body;
    }
    throw ApiException('Unexpected server response.');
  }

  List<dynamic> _decodeList(http.Response response) {
    final dynamic body = _parseBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (body is Map<String, dynamic>) {
        throw ApiException(body['error']?.toString() ?? 'Request failed.');
      }
      throw ApiException('Request failed.');
    }
    if (body is List<dynamic>) {
      return body;
    }
    throw ApiException('Unexpected server response.');
  }

  dynamic _parseBody(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

const api = ApiClient();
const hallCategories = ['All', 'Luxury', 'Outdoor', 'Indoor', 'Budget', 'Party', 'Corporate', 'Cultural', 'Intimate', 'Romantic'];
const hallSortOptions = {
  'featured': 'Featured first',
  'nearest': 'Nearest first',
  'price_low': 'Lowest price',
  'price_high': 'Highest price',
  'rating': 'Top rated',
  'capacity': 'Largest capacity',
  'name': 'Name A-Z',
};
const adminBookingStatusFilters = {
  'All': '',
  'Pending': 'pending',
  'Approved': 'approved',
  'Rejected': 'rejected',
  'Cancelled': 'cancelled',
};
const adminBookingSortOptions = {
  'newest': 'Newest first',
  'oldest': 'Oldest first',
  'event_date': 'Event date',
  'hall': 'Hall name',
  'customer': 'Customer name',
  'guest_count': 'Largest guest count',
  'status': 'Status',
};
const customerBookingStatusFilters = {
  'All': '',
  'Pending': 'pending',
  'Approved': 'approved',
  'Rejected': 'rejected',
  'Cancelled': 'cancelled',
};
const customerBookingSortOptions = {
  'event_date': 'Event date',
  'newest': 'Newest first',
  'oldest': 'Oldest first',
  'hall': 'Hall name',
  'guest_count': 'Largest guest count',
  'status': 'Status',
};
const hallImageCatalog = <String, List<String>>{
  'royal orchid hall': [
    'assets/images/halls/royal_fort/hall1.jpg',
    'assets/images/halls/royal_fort/hall2.jpg',
    'assets/images/halls/royal_fort/hall3.jpg',
  ],
  'galaxy hall': [
    'assets/images/halls/galaxy/hall1.jpg',
    'assets/images/halls/galaxy/hall2.jpg',
    'assets/images/halls/galaxy/hall3.jpg',
  ],
  'dream garden': [
    'assets/images/halls/dream_garden/hall1.jpg',
    'assets/images/halls/dream_garden/hall2.jpg',
    'assets/images/halls/dream_garden/hall3.jpg',
  ],
  'pearl palace': [
    'assets/images/halls/pearl_palace/hall1.jpg',
    'assets/images/halls/pearl_palace/hall2.jpg',
    'assets/images/halls/pearl_palace/hall3.jpg',
  ],
  'sunshine villa': [
    'assets/images/halls/sunshine_villa/hall1.jpg',
    'assets/images/halls/sunshine_villa/hall2.jpg',
    'assets/images/halls/sunshine_villa/hall3.jpg',
  ],
};

List<String> hallImagesFor(Map<String, dynamic> hall) {
  final apiImages = (hall['image_urls'] as List<dynamic>? ?? const [])
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
  if (apiImages.isNotEmpty) {
    return apiImages;
  }
  final name = hall['name']?.toString().toLowerCase() ?? '';
  return hallImageCatalog[name] ?? const ['assets/hall_id_1.jpg'];
}

String hallPrimaryImage(Map<String, dynamic> hall) => hallImagesFor(hall).first;

bool isNetworkImagePath(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

Widget buildHallImage(
  String path, {
  required double height,
  required double width,
  BoxFit fit = BoxFit.cover,
}) {
  if (isNetworkImagePath(path)) {
    return Image.network(
      path,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
  // Flutter web's debug server may not serve declared assets consistently.
  // For anything under `assets/...`, fetch it from Flask where we serve assets.
  if (kIsWeb && path.startsWith('assets/')) {
    final relpath = path.substring('assets/'.length);
    final url = '$baseUrl/app_assets/$relpath';
    return Image.network(
      url,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        width: width,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
  return Image.asset(path, height: height, width: width, fit: fit);
}

double calculateAdjustedCost(double baseRent, int guestCount) {
  const baseCapacity = 30;
  const costPer30Guests = 20000.0;

  if (guestCount <= baseCapacity) {
    return baseRent;
  }

  final additionalGroups = (guestCount - baseCapacity) ~/ baseCapacity;
  return baseRent + (additionalGroups * costPer30Guests);
}

Future<void> saveSession(String role, Map<String, dynamic> user) async {
  await writeSessionValue(
    'session_user',
    jsonEncode({'role': role, 'user': user}),
  );
}

Future<void> clearSession() async {
  await removeSessionValue('session_user');
}

void showAppSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ),
  );
}

String formatMessageTimestamp(String rawValue) {
  final parsed = DateTime.tryParse(rawValue);
  if (parsed == null) {
    return rawValue;
  }
  return DateFormat('MMM d, yyyy h:mm a').format(parsed.toLocal());
}

int? bookingIdFromMap(Map<String, dynamic> booking) {
  final bookingId = booking['hall_booking_id'] ?? booking['booking_id'];
  if (bookingId is int) {
    return bookingId;
  }
  return int.tryParse(bookingId?.toString() ?? '');
}

class BookingMessagesDialog extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> messages;
  final String sendButtonLabel;
  final String viewerRole;
  final Future<void> Function(String message) onSend;
  final Future<List<Map<String, dynamic>>> Function()? loadMessages;

  const BookingMessagesDialog({
    super.key,
    required this.title,
    required this.messages,
    required this.sendButtonLabel,
    required this.viewerRole,
    required this.onSend,
    this.loadMessages,
  });

  @override
  State<BookingMessagesDialog> createState() => _BookingMessagesDialogState();
}

class _BookingMessagesDialogState extends State<BookingMessagesDialog> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late List<Map<String, dynamic>> _messages;
  Timer? _refreshTimer;
  bool _sending = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
    _messages = List<Map<String, dynamic>>.from(widget.messages);
    if (widget.loadMessages != null) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshMessages(),
      );
      unawaited(_refreshMessages());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _refreshMessages() async {
    if (_refreshing || widget.loadMessages == null) {
      return;
    }
    _refreshing = true;
    try {
      final latestMessages = await widget.loadMessages!();
      if (!mounted) return;
      setState(() {
        _messages = latestMessages;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      if (!mounted) return;
      _controller.clear();
      await _refreshMessages();
      if (!mounted) return;
      showAppSnackBar(context, 'Message sent.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_messages.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    const Text('No messages yet. Start the conversation here.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  controller: _scrollController,
                  shrinkWrap: true,
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final senderRole = message['sender_role']?.toString() ?? '';
                    final isOwnMessage = senderRole == widget.viewerRole;
                    return Align(
                      alignment: isOwnMessage
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 340,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOwnMessage
                              ? const Color(0xFFF3E8EC)
                              : const Color(0xFFECECEC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['sender_name']?.toString() ??
                                  (isOwnMessage ? 'You' : 'Customer'),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(message['message']?.toString() ?? ''),
                            const SizedBox(height: 6),
                            Text(
                              formatMessageTimestamp(
                                message['created_at']?.toString() ?? '',
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Type your reply',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending...' : widget.sendButtonLabel),
        ),
      ],
    );
  }
}

class BookingMessagePreview extends StatelessWidget {
  final List<Map<String, dynamic>> messages;

  const BookingMessagePreview({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Text(
        'No messages yet.',
        style: TextStyle(color: Colors.grey),
      );
    }

    final previewMessages =
        messages.length <= 2 ? messages : messages.sublist(messages.length - 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: previewMessages.map((message) {
        final sender =
            message['sender_name']?.toString() ??
            (message['sender_role'] == 'admin' ? 'Admin' : 'Customer');
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$sender: ${message['message']}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade800),
          ),
        );
      }).toList(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF42213D), Color(0xFF7C2D47), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                AppLocalizations.of(context)!.appTitle,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.landingSubtitle,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(initialLogin: true),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: const Color(0xFF1F2937),
                ),
                child: Text(AppLocalizations.of(context)!.login),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(initialLogin: false),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: Colors.white,
                ),
                child: Text(AppLocalizations.of(context)!.register),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.availableHalls,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.fullHallList,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                      ),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<List<dynamic>>(
                      future: api.getHalls(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          );
                        }
                        final halls = snapshot.data ?? [];
                        if (halls.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.noHallsAvailable,
                            ),
                          );
                        }
                        return Column(
                          children: halls
                              .map(
                                (hall) => HallPreviewCard(
                                  hall: Map<String, dynamic>.from(hall as Map),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => HallDetailPage(
                                          user: const {},
                                          hall: Map<String, dynamic>.from(hall),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  final bool initialLogin;

  const AuthScreen({super.key, this.initialLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _favoriteCategory = 'Any';
  bool _isLogin = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialLogin;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_isLogin) {
        final data = await api.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        final role = data['role']?.toString() ?? '';
        final user = Map<String, dynamic>.from(data['user'] as Map? ?? {});
        if (role.isEmpty || user.isEmpty) {
          throw ApiException(
              'Login succeeded but the server returned an incomplete user session.');
        }
        await saveSession(role, user);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => buildHomeForRole(role, user)),
          (_) => false,
        );
      } else {
        await api.register({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
          'favorite_category': _favoriteCategory,
        });
        if (!mounted) return;
        showAppSnackBar(context, 'Registration successful. Please log in.');
        setState(() => _isLogin = true);
        _passwordController.clear();
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isLogin
              ? AppLocalizations.of(context)!.login
              : AppLocalizations.of(context)!.register)),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFDADAD6), Color(0xFFFFFFFF)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1F2937), Color(0xFF7C2D47)],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLogin
                                    ? AppLocalizations.of(context)!.welcomeBack
                                    : AppLocalizations.of(context)!
                                        .createAccount,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isLogin
                                    ? AppLocalizations.of(context)!
                                        .loginSubtitle
                                    : AppLocalizations.of(context)!
                                        .registerSubtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                                labelText:
                                    AppLocalizations.of(context)!.fullName),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                    ? AppLocalizations.of(context)!.enterName
                                    : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                              labelText: AppLocalizations.of(context)!.email),
                          validator: (value) => value == null ||
                                  !value.contains('@')
                              ? AppLocalizations.of(context)!.enterValidEmail
                              : null,
                        ),
                        const SizedBox(height: 12),
                        if (!_isLogin) ...[
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!.phone),
                            validator: (value) =>
                                value == null || value.trim().length < 10
                                    ? AppLocalizations.of(context)!.enterPhone
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _favoriteCategory,
                            decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!
                                    .preferredHallType),
                            items: [
                              {
                                'value': 'Any',
                                'display': AppLocalizations.of(context)!.any
                              },
                              {
                                'value': 'Luxury',
                                'display': AppLocalizations.of(context)!.luxury
                              },
                              {
                                'value': 'Outdoor',
                                'display': AppLocalizations.of(context)!.outdoor
                              },
                              {
                                'value': 'Indoor',
                                'display': AppLocalizations.of(context)!.indoor
                              },
                              {
                                'value': 'Budget',
                                'display': AppLocalizations.of(context)!.budget
                              }
                            ]
                                .map((item) => DropdownMenuItem<String>(
                                    value: item['value'] as String,
                                    child: Text(item['display'] as String)))
                                .toList(),
                            onChanged: (value) => setState(
                                () => _favoriteCategory = value ?? 'Any'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(context)!.password),
                          validator: (value) => value == null ||
                                  value.length < 6
                              ? AppLocalizations.of(context)!.passwordMinLength
                              : null,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: Text(_submitting
                              ? AppLocalizations.of(context)!.pleaseWait
                              : _isLogin
                                  ? AppLocalizations.of(context)!.login
                                  : AppLocalizations.of(context)!
                                      .createAccount),
                        ),
                        TextButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin
                                ? AppLocalizations.of(context)!
                                    .needAccountRegister
                                : AppLocalizations.of(context)!
                                    .alreadyRegisteredLogin,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const CustomerDashboard({super.key, required this.user});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  late Map<String, dynamic> _user;
  late Future<List<dynamic>> _featuredFuture;
  late Future<List<dynamic>> _recommendedFuture;
  late Future<List<dynamic>> _allHallsFuture;

  @override
  void initState() {
    super.initState();
    _user = Map<String, dynamic>.from(widget.user);
    _reloadHallSections();
  }

  void _reloadHallSections() {
    _featuredFuture = api.getHalls(featured: true);
    _recommendedFuture = api.getHalls(
      category: (_user['favorite_category']?.toString() ?? 'Any') == 'Any'
          ? ''
          : _user['favorite_category'].toString(),
    );
    _allHallsFuture = api.getHalls();
  }

  Future<void> _logout() async {
    await clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (_) => false,
    );
  }

  Future<void> _editProfile() async {
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerProfilePage(user: _user),
      ),
    );
    if (updated != null && mounted) {
      setState(() {
        _user = updated;
        _reloadHallSections();
      });
      await saveSession('customer', updated);
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.selectLanguage),
        content: RadioGroup<String>(
          groupValue: languageProvider.currentLanguage,
          onChanged: (value) {
            if (value != null) {
              languageProvider.setLanguage(value);
              Navigator.of(context).pop();
            }
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('English'),
                leading: Radio<String>(value: 'en'),
              ),
              ListTile(
                title: Text('اردو'),
                leading: Radio<String>(value: 'ur'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName =
        (_user['name']?.toString() ?? 'Customer').split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.customerDashboard),
        actions: [
          IconButton(
            onPressed: () => _showLanguageDialog(context),
            icon: const Icon(Icons.language),
            tooltip: AppLocalizations.of(context)!.changeLanguage,
          ),
          IconButton(
              onPressed: _editProfile, icon: const Icon(Icons.person_outline)),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2937), Color(0xFF7C2D47)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundImage:
                      (_user['profile_image']?.toString().isNotEmpty ?? false)
                          ? NetworkImage(_user['profile_image'].toString())
                          : null,
                  child:
                      (_user['profile_image']?.toString().isNotEmpty ?? false)
                          ? null
                          : const Icon(Icons.person, size: 34),
                ),
                const SizedBox(height: 12),
                Text(
                  '${AppLocalizations.of(context)!.welcome}, $firstName',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.of(context)!.preferredCategory}: ${_user['favorite_category'] ?? AppLocalizations.of(context)!.any}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionCard(
                title: AppLocalizations.of(context)!.browseHalls,
                subtitle: AppLocalizations.of(context)!.browseHallsSubtitle,
                icon: Icons.storefront_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HallCatalogPage(user: _user)),
                  );
                },
              ),
              _ActionCard(
                title: AppLocalizations.of(context)!.myBookings,
                subtitle: AppLocalizations.of(context)!.myBookingsSubtitle,
                icon: Icons.event_available_outlined,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MyBookingsPage(user: _user)),
                  );
                },
              ),
              _ActionCard(
                title: AppLocalizations.of(context)!.updateProfile,
                subtitle: AppLocalizations.of(context)!.updateProfileSubtitle,
                icon: Icons.edit_outlined,
                onTap: _editProfile,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.allHalls,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HallCatalogPage(user: _user),
                    ),
                  );
                },
                child: Text(AppLocalizations.of(context)!.openFullCatalog),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: _allHallsFuture,
            builder: (context, snapshot) {
              final halls = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (halls.isEmpty) {
                return Text(AppLocalizations.of(context)!.noHallsAvailable);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.showingHalls(halls.length),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 10),
                  ...halls.map((hall) => HallPreviewCard(
                        hall: Map<String, dynamic>.from(hall as Map),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HallDetailPage(
                                user: _user,
                                hall: Map<String, dynamic>.from(hall),
                              ),
                            ),
                          );
                        },
                      )),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Featured halls', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: _featuredFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final halls = snapshot.data ?? [];
              if (halls.isEmpty) {
                return const Text('No halls available right now.');
              }
              return Column(
                children: halls
                    .map((hall) => HallPreviewCard(
                          hall: Map<String, dynamic>.from(hall as Map),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HallDetailPage(
                                  user: _user,
                                  hall: Map<String, dynamic>.from(hall),
                                ),
                              ),
                            );
                          },
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Recommended for you',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: _recommendedFuture,
            builder: (context, snapshot) {
              final halls = snapshot.data ?? [];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (halls.isEmpty) {
                return const Text(
                    'Update your preferred category to get suggestions.');
              }
              return Column(
                children: halls
                    .map((hall) => HallPreviewCard(
                          hall: Map<String, dynamic>.from(hall as Map),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HallDetailPage(
                                  user: _user,
                                  hall: Map<String, dynamic>.from(hall),
                                ),
                              ),
                            );
                          },
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class HallCatalogPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const HallCatalogPage({super.key, required this.user});

  @override
  State<HallCatalogPage> createState() => _HallCatalogPageState();
}

class _HallCatalogPageState extends State<HallCatalogPage> {
final _searchController = TextEditingController();
final _searchFocusNode = FocusNode();
  final _cityController = TextEditingController();
final _cityFocusNode = FocusNode();
  final _nearestLocationController = TextEditingController();
final _nearestFocusNode = FocusNode();
  final _minCapacityController = TextEditingController();
  final _maxRentController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedSortBy = 'featured';
  late Future<List<dynamic>> _hallsFuture;
  List<String> _searchSuggestions = const [];
  List<String> _citySuggestions = const [];
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _hallsFuture = _loadHalls();
    unawaited(_loadSearchSuggestions());
  }

  Future<List<dynamic>> _loadHalls() {
    return api.getHalls(
      query: _searchController.text.trim(),
      city: _cityController.text.trim(),
      nearestTo: _nearestLocationController.text.trim(),
      category: _selectedCategory,
      sortBy: _selectedSortBy,
      minCapacity: int.tryParse(_minCapacityController.text.trim()),
      maxRent: int.tryParse(_maxRentController.text.trim()),
    );
  }

  void _applyFilters() {
    setState(() => _hallsFuture = _loadHalls());
  }

  Future<void> _loadSearchSuggestions() async {
    try {
      final halls = await api.getHalls();
      if (!mounted) return;
      final suggestions = <String>{};
      for (final item in halls) {
        final hall = Map<String, dynamic>.from(item as Map);
        final hallName = hall['name']?.toString().trim() ?? '';
        final city = hall['location']?.toString().trim() ?? '';
        if (hallName.isNotEmpty) {
          suggestions.add(hallName);
        }
        if (city.isNotEmpty) {
          suggestions.add(city);
        }
      }
      setState(() {
        _searchSuggestions = suggestions.toList()
          ..sort(
            (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
          );
        _citySuggestions = halls
            .map((item) => Map<String, dynamic>.from(item as Map))
            .map((hall) => hall['location']?.toString().trim() ?? '')
            .where((city) => city.isNotEmpty)
            .toSet()
            .toList()
          ..sort(
            (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
          );
      });
    } catch (_) {}
  }

  Iterable<String> _matchingSearchSuggestions(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const [];
    }

    final startsWithMatches = <String>[];
    final containsMatches = <String>[];
    for (final suggestion in _searchSuggestions) {
      final candidate = suggestion.toLowerCase();
      if (candidate.startsWith(normalized)) {
        startsWithMatches.add(suggestion);
      } else if (candidate.contains(normalized)) {
        containsMatches.add(suggestion);
      }
    }
    return [...startsWithMatches, ...containsMatches].take(8);
  }

  Iterable<String> _matchingCitySuggestions(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _citySuggestions.take(8);
    }
    final startsWithMatches = <String>[];
    final containsMatches = <String>[];
    for (final suggestion in _citySuggestions) {
      final candidate = suggestion.toLowerCase();
      if (candidate.startsWith(normalized)) {
        startsWithMatches.add(suggestion);
      } else if (candidate.contains(normalized)) {
        containsMatches.add(suggestion);
      }
    }
    return [...startsWithMatches, ...containsMatches].take(8);
  }

  void _scheduleSearchApply() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () {
        if (!mounted) return;
        _applyFilters();
      },
    );
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _cityController.clear();
    _nearestLocationController.clear();
    _minCapacityController.clear();
    _maxRentController.clear();
    setState(() {
      _selectedCategory = 'All';
      _selectedSortBy = 'featured';
      _hallsFuture = _loadHalls();
    });
  }

  String? _filtersSummary() {
    final parts = <String>[];
    final search = _searchController.text.trim();
    final city = _cityController.text.trim();
    final nearest = _nearestLocationController.text.trim();
    final minCapacity = _minCapacityController.text.trim();
    final maxRent = _maxRentController.text.trim();

    if (search.isNotEmpty) parts.add('Search: $search');
    if (city.isNotEmpty) parts.add('City: $city');
    if (nearest.isNotEmpty) parts.add('Nearest: $nearest');
    if (_selectedCategory != 'All') parts.add('Category: $_selectedCategory');
    if (_selectedSortBy != 'featured') {
      parts.add('Sort: ${hallSortOptions[_selectedSortBy] ?? _selectedSortBy}');
    }
    if (minCapacity.isNotEmpty) parts.add('Min guests: $minCapacity');
    if (maxRent.isNotEmpty) parts.add('Max rent: $maxRent');

    if (parts.isEmpty) {
      return null;
    }
    return parts.join('  •  ');
  }

@override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _cityController.dispose();
    _cityFocusNode.dispose();
    _nearestLocationController.dispose();
    _nearestFocusNode.dispose();
    _minCapacityController.dispose();
    _maxRentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Halls')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
RawAutocomplete<String>(
                    textEditingController: _searchController,
                    focusNode: _searchFocusNode,
                    optionsBuilder: (textEditingValue) =>
                        _matchingSearchSuggestions(textEditingValue.text),
                    onSelected: (selection) {
                      _searchController.text = selection;
                      _applyFilters();
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (_) => _scheduleSearchApply(),
                        onSubmitted: (_) {
                          onFieldSubmitted();
                          _applyFilters();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Search by hall or city',
                          hintText: 'Type hall name or city',
                          suffixIcon: Icon(Icons.search),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final matches = options.toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 480,
                              maxHeight: 240,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final option = matches[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_searching),
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
RawAutocomplete<String>(
                    textEditingController: _cityController,
                    focusNode: _cityFocusNode,
                    optionsBuilder: (textEditingValue) =>
                        _matchingCitySuggestions(textEditingValue.text),
                    onSelected: (selection) {
                      _cityController.text = selection;
                      _applyFilters();
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (_) => _scheduleSearchApply(),
                        onSubmitted: (_) {
                          onFieldSubmitted();
                          _applyFilters();
                        },
                        decoration: const InputDecoration(
                          labelText: 'City filter',
                          hintText: 'Only halls in this city',
                          suffixIcon: Icon(Icons.location_city_outlined),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final matches = options.toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 480,
                              maxHeight: 220,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final option = matches[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.location_city_outlined),
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
RawAutocomplete<String>(
                    textEditingController: _nearestLocationController,
                    focusNode: _nearestFocusNode,
                    optionsBuilder: (textEditingValue) =>
                        _matchingCitySuggestions(textEditingValue.text),
                    onSelected: (selection) {
                      _nearestLocationController.text = selection;
                      _applyFilters();
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (_) => _scheduleSearchApply(),
                        onSubmitted: (_) {
                          onFieldSubmitted();
                          _applyFilters();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Nearest to',
                          hintText: 'Sort halls by nearest city',
                          suffixIcon: Icon(Icons.near_me_outlined),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final matches = options.toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 480,
                              maxHeight: 220,
                            ),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shrinkWrap: true,
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final option = matches[index];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.near_me_outlined),
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    items: hallCategories
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) =>
                        setState(() {
                          _selectedCategory = value ?? 'All';
                          _scheduleSearchApply();
                        }),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSortBy,
                    items: hallSortOptions.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() {
                      _selectedSortBy = value ?? 'featured';
                      _scheduleSearchApply();
                    }),
                    decoration: const InputDecoration(labelText: 'Sort by'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minCapacityController,
                          onChanged: (_) => _scheduleSearchApply(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Min guests'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _maxRentController,
                          onChanged: (_) => _scheduleSearchApply(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Max rent (Rs.)'),
                        ),
                      ),
                    ],
                  ),
                  if (_filtersSummary() != null) ...[
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _filtersSummary()!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _applyFilters,
                          child: const Text('Apply filters'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<dynamic>>(
            future: _hallsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(snapshot.error.toString());
              }
              final halls = snapshot.data ?? [];
              if (halls.isEmpty) {
                return const Text('No halls matched your filters.');
              }
              return Column(
                children: halls
                    .map((hall) => HallPreviewCard(
                          hall: Map<String, dynamic>.from(hall as Map),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HallDetailPage(
                                  user: widget.user,
                                  hall: Map<String, dynamic>.from(hall),
                                ),
                              ),
                            );
                          },
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class HallDetailPage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> hall;

  const HallDetailPage({super.key, required this.user, required this.hall});

  @override
  State<HallDetailPage> createState() => _HallDetailPageState();
}

class _HallDetailPageState extends State<HallDetailPage> {
  final _dateController = TextEditingController();
  final _guestCountController = TextEditingController(text: '200');
  final _requestController = TextEditingController();
  final _notesController = TextEditingController();
  final _feedbackController = TextEditingController();
  String _eventType = 'Wedding';
  int _feedbackRating = 5;
  bool _submitting = false;
  bool _submittingFeedback = false;
  bool _hydratedFeedbackDraft = false;
  List<String> _latestAvailableDates = const [];
  late Future<Map<String, dynamic>> _availabilityFuture;
  late Future<Map<String, dynamic>> _feedbackFuture;
  late final List<String> _galleryImages;
  late String _selectedImage;
  List<Map<String, dynamic>> _selectedMenus = [];
  double _menuExtraCost = 0.0;

  @override
  void initState() {
    super.initState();
    _availabilityFuture = api.getAvailability(widget.hall['hall_id'] as int);
    _feedbackFuture = api.getHallFeedback(widget.hall['hall_id'] as int);
    _galleryImages = hallImagesFor(widget.hall);
    _selectedImage = _galleryImages.first;
    _guestCountController.addListener(_onGuestCountChanged);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _guestCountController.removeListener(_onGuestCountChanged);
    _guestCountController.dispose();
    _requestController.dispose();
    _notesController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _onGuestCountChanged() {
    // Update estimated cost live while user edits guest count.
    if (!mounted) return;
    setState(() {});
  }

  void _onMenuSelected(List<Map<String, dynamic>> menus, double extraCost) {
    setState(() {
      _selectedMenus = menus;
      _menuExtraCost = extraCost;
    });
  }

  bool _isSelectedDateAvailable(List<String> availableDates) {
    final selectedDate = _dateController.text.trim();
    if (selectedDate.isEmpty) {
      return false;
    }
    return availableDates.contains(selectedDate);
  }

  Future<void> _bookHall() async {
    if (_dateController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Choose a booking date.', isError: true);
      return;
    }

    try {
      final availability = await _availabilityFuture;
      final availableDates =
          (availability['available_dates'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList();
      if (!_isSelectedDateAvailable(availableDates)) {
        if (!mounted) return;
        showAppSnackBar(
          context,
          'That date is no longer available. Please choose another one.',
          isError: true,
        );
        setState(() {
          _availabilityFuture = api.getAvailability(widget.hall['hall_id'] as int);
        });
        return;
      }
    } catch (_) {}

    setState(() => _submitting = true);
    try {
      await api.createBooking({
        'hall_id': widget.hall['hall_id'],
        'customer_id': widget.user['id'],
        'booking_date': _dateController.text.trim(),
        'event_type': _eventType,
        'guest_count': int.tryParse(_guestCountController.text.trim()) ?? 100,
        'special_request': _requestController.text.trim(),
        'additional_notes': _notesController.text.trim(),
        'menu_items': _selectedMenus.map((menu) => {'menu_id': menu['menu_id'], 'quantity': menu['quantity']}).toList(),
      });
      if (!mounted) return;
      showAppSnackBar(context, 'Booking request submitted.');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _dateController.text = picked.toIso8601String().split('T').first;
      setState(() {});
    }
  }

  Future<void> _submitFeedback() async {
    final customerId = widget.user['id'] as int?;
    if (customerId == null) {
      showAppSnackBar(context, 'Login to submit feedback.', isError: true);
      return;
    }
    if (_feedbackController.text.trim().isEmpty) {
      showAppSnackBar(context, 'Write your feedback first.', isError: true);
      return;
    }

    setState(() => _submittingFeedback = true);
    try {
      await api.submitHallFeedback(
        widget.hall['hall_id'] as int,
        {
          'customer_id': customerId,
          'rating': _feedbackRating,
          'comment': _feedbackController.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() {
        _hydratedFeedbackDraft = false;
        _feedbackFuture = api.getHallFeedback(widget.hall['hall_id'] as int);
      });
      showAppSnackBar(context, 'Feedback submitted.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submittingFeedback = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hall = widget.hall;
    final theme = Theme.of(context);
    final isGuest = widget.user['id'] == null;
    final baseRent = (hall['rent'] as num?)?.toDouble() ?? 0.0;
    final guestCount = int.tryParse(_guestCountController.text.trim()) ?? 0;
    final estimated = calculateAdjustedCost(baseRent, guestCount) + _menuExtraCost;
    final distance = hall['distance_km'];
    final selectedDateAvailable = _isSelectedDateAvailable(_latestAvailableDates);
    return Scaffold(
      appBar: AppBar(title: Text(hall['name']?.toString() ?? 'Hall details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1F2937), Color(0xFF7C2D47)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C2D47).withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        buildHallImage(
                          _selectedImage,
                          height: 280,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.14),
                                  Colors.black.withValues(alpha: 0.55),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 18,
                          right: 18,
                          bottom: 18,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _detailBadge(
                                          context,
                                          icon: Icons.place_outlined,
                                          label: hall['location']?.toString() ??
                                              'Location not set',
                                        ),
                                        _detailBadge(
                                          context,
                                          icon: Icons.celebration_outlined,
                                          label: hall['category']?.toString() ??
                                              'Category',
                                        ),
                                        if (distance != null)
                                          _detailBadge(
                                            context,
                                            icon: Icons.near_me_outlined,
                                            label:
                                                '${distance.toString()} km away',
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      hall['name']?.toString() ?? '',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      hall['description']?.toString() ??
                                          'A polished venue for memorable events.',
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.88,
                                        ),
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Starting from',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs. ${hall['rent']}',
                                      style:
                                          theme.textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 94,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final image = _galleryImages[index];
                        final selected = image == _selectedImage;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedImage = image),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 124,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.14),
                                width: selected ? 1.8 : 1,
                              ),
                              color: Colors.white.withValues(
                                alpha: selected ? 0.16 : 0.08,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: buildHallImage(
                                image,
                                height: 86,
                                width: 116,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: _galleryImages.length,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _infoPanel(
                        context,
                        icon: Icons.groups_2_outlined,
                        title: 'Capacity',
                        value: '${hall['capacity']} guests',
                      ),
                      _infoPanel(
                        context,
                        icon: Icons.payments_outlined,
                        title: 'Estimated total',
                        value:
                            'Rs. ${estimated.toStringAsFixed(0)} for $guestCount guests',
                      ),
                      _infoPanel(
                        context,
                        icon: Icons.call_outlined,
                        title: 'Contact',
                        value:
                            '${hall['contact_person']} - ${hall['phone_number']}',
                      ),
                      _infoPanel(
                        context,
                        icon: Icons.mail_outline,
                        title: 'Email',
                        value: hall['email']?.toString().isNotEmpty == true
                            ? hall['email'].toString()
                            : 'Contact details available on request',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            color: const Color(0xFFFFFBF7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick overview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Photos stay visible here so guests can compare the venue while checking availability, pricing, and booking details.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _feedbackFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ?? const <String, dynamic>{};
              final averageRating =
                  (data['average_rating'] as num?)?.toDouble() ?? 0.0;
              final feedbackCount = (data['feedback_count'] as num?)?.toInt() ?? 0;
              final feedbackItems =
                  (data['feedback'] as List<dynamic>? ?? const [])
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .toList();
              final customerId = widget.user['id'] as int?;
              if (!_hydratedFeedbackDraft && customerId != null) {
                Map<String, dynamic>? ownFeedback;
                for (final item in feedbackItems) {
                  if (item['customer_id'] == customerId) {
                    ownFeedback = item;
                    break;
                  }
                }
                if (ownFeedback != null) {
                  _feedbackController.text =
                      ownFeedback['comment']?.toString() ?? '';
                  _feedbackRating =
                      (ownFeedback['rating'] as num?)?.toInt() ?? 5;
                }
                _hydratedFeedbackDraft = true;
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Feedback',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.star_rounded, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text(
                            feedbackCount == 0
                                ? 'No ratings yet'
                                : '${averageRating.toStringAsFixed(1)} ($feedbackCount)',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isGuest) ...[
                        DropdownButtonFormField<int>(
                          initialValue: _feedbackRating,
                          decoration: const InputDecoration(labelText: 'Your rating'),
                          items: const [1, 2, 3, 4, 5]
                              .map(
                                (rating) => DropdownMenuItem(
                                  value: rating,
                                  child: Text('$rating star${rating == 1 ? '' : 's'}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _feedbackRating = value ?? 5),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _feedbackController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Share your experience',
                            hintText: 'Food setup, decor, staff, parking, timing...',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                            child: FilledButton.tonal(
                              onPressed: _submittingFeedback ? null : _submitFeedback,
                              child: Text(
                                _submittingFeedback
                                    ? 'Submitting...'
                                    : feedbackItems.any(
                                            (item) =>
                                                item['customer_id'] ==
                                                widget.user['id'],
                                          )
                                        ? 'Update feedback'
                                        : 'Submit feedback',
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                      ],
                      if (feedbackItems.isEmpty)
                        Text(
                          isGuest
                              ? 'No feedback available yet.'
                              : 'No feedback yet. Be the first to review this hall.',
                        )
                      else
                        ...feedbackItems.map(
                          (item) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F2F4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['customer_name']?.toString() ??
                                            'Customer',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item['rating']} / 5',
                                      style: TextStyle(
                                        color: Colors.amber.shade800,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(item['comment']?.toString() ?? ''),
                                const SizedBox(height: 6),
                                Text(
                                  formatMessageTimestamp(
                                    item['created_at']?.toString() ?? '',
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _availabilityFuture,
            builder: (context, snapshot) {
              final availableDates =
                  (snapshot.data?['available_dates'] as List<dynamic>? ??
                          const [])
                      .map((item) => item.toString())
                      .toList();
              _latestAvailableDates = availableDates;
              final dates = availableDates.take(8).toList();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next available dates',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (dates.isEmpty)
                        const Text('Loading availability...')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dates
                              .map(
                                (item) => ActionChip(
                                  label: Text(item),
                                  onPressed: isGuest
                                      ? null
                                      : () {
                                          _dateController.text = item;
                                          setState(() {});
                                        },
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (isGuest)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in to request a booking',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Everyone can browse hall photos and details. Login or register when you are ready to send a booking request.',
                      style:
                          TextStyle(color: Colors.grey.shade700, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const AuthScreen(initialLogin: true),
                          ),
                        );
                      },
                      child: const Text('Login to continue'),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    TextField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: const InputDecoration(
                        labelText: 'Booking date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_dateController.text.trim().isNotEmpty &&
                        !selectedDateAvailable)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Selected date is not in the current availability list.',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: _eventType,
                      items: const [
                        'Wedding',
                        'Walima',
                        'Mehndi',
                        'Birthday',
                        'Corporate'
                      ]
                          .map((item) =>
                              DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _eventType = value ?? 'Wedding'),
                      decoration:
                          const InputDecoration(labelText: 'Event type'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _guestCountController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Guest count'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _requestController,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: 'Special request'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional notes',
                        hintText: 'Any additional details for the manager',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FoodMenuScreen(
                                    hallId: widget.hall['hall_id'] as int,
                                    hallName: widget.hall['name'] as String,
                                    onMenuSelected: _onMenuSelected,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.restaurant),
                            label: const Text('Select Food'),
                          ),
                        ),
                        if (_selectedMenus.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Chip(
                            label: Text('${_selectedMenus.length} items'),
                            backgroundColor: Colors.green.shade100,
                          ),
                        ],
                      ],
                    ),
                    if (_menuExtraCost > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Food cost: Rs. ${_menuExtraCost.toStringAsFixed(0)}',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _submitting ? null : _bookHall,
                      child: Text(
                        _submitting ? 'Submitting...' : 'Request booking',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _infoPanel(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyBookingsPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const MyBookingsPage({super.key, required this.user});

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  late Future<List<dynamic>> _bookingsFuture;
  final TextEditingController _bookingSearchController =
      TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _bookingFilter = 'All';
  String _bookingSortBy = 'event_date';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _bookingsFuture = api.getMyBookings(widget.user['id'] as int);
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _bookingSearchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _bookingsFuture = api.getMyBookings(widget.user['id'] as int);
    });
  }

  Future<void> _refreshSilently() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _bookingsFuture = api.getMyBookings(widget.user['id'] as int);
    });
  }

  Future<List<Map<String, dynamic>>> _loadBookingMessages(int bookingId) async {
    final bookings = await api.getMyBookings(widget.user['id'] as int);
    for (final item in bookings) {
      final booking = Map<String, dynamic>.from(item as Map);
      if (bookingIdFromMap(booking) == bookingId) {
        return ((booking['messages'] as List?) ?? const [])
            .map((message) => Map<String, dynamic>.from(message as Map))
            .toList();
      }
    }
    return const [];
  }

  Future<void> _cancelBooking(int bookingId) async {
    try {
      await api.cancelBooking(bookingId, widget.user['id'] as int);
      if (!mounted) return;
      showAppSnackBar(context, AppLocalizations.of(context)!.bookingCancelled);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _addToCalendar(Map<String, dynamic> booking) async {
    try {
      final hallName = booking['hall_name']?.toString() ?? 'Hall';
      final eventType = booking['event_type']?.toString() ?? 'Event';
      final bookingDate = booking['booking_date']?.toString() ?? '';
      final guestCount = booking['guest_count']?.toString() ?? '';

      final title = '$eventType at $hallName';
      final description =
          'Event: $eventType\nHall: $hallName\nGuests: $guestCount\nDate: $bookingDate';

      await CalendarService.addBookingToCalendar(
        title: title,
        description: description,
        startDate: DateTime.tryParse(bookingDate) ?? DateTime.now(),
        endDate: (DateTime.tryParse(bookingDate) ?? DateTime.now())
            .add(const Duration(days: 1)),
        location: hallName,
      );

      if (!mounted) return;
      showAppSnackBar(context, AppLocalizations.of(context)!.addedToCalendar);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _openMessages(Map<String, dynamic> booking) async {
    final bookingId = bookingIdFromMap(booking);
    if (bookingId == null) {
      showAppSnackBar(context, 'Booking ID is missing.', isError: true);
      return;
    }
    final messages = ((booking['messages'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final didUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => BookingMessagesDialog(
        title: 'Messages for ${booking['hall_name'] ?? 'booking'}',
        messages: messages,
        sendButtonLabel: 'Send reply',
        viewerRole: 'customer',
        loadMessages: () => _loadBookingMessages(bookingId),
        onSend: (message) async {
          await api.sendCustomerBookingMessage(
            bookingId,
            widget.user['id'] as int,
            message,
          );
        },
      ),
    );
    if (didUpdate == true && mounted) {
      showAppSnackBar(context, 'Message sent.');
      await _refresh();
    }
  }

  List<Map<String, dynamic>> _filteredBookings(List<dynamic> rawBookings) {
    final query = _bookingSearchController.text.trim().toLowerCase();
    final normalizedStatusFilter =
        customerBookingStatusFilters[_bookingFilter] ?? '';

    final filtered = rawBookings
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      final hall = booking['hall_name']?.toString().toLowerCase() ?? '';
      final eventType = booking['event_type']?.toString().toLowerCase() ?? '';
      final bookingDate = booking['booking_date']?.toString().toLowerCase() ?? '';
      final guestCount = booking['guest_count']?.toString().toLowerCase() ?? '';

      final statusMatches = normalizedStatusFilter.isEmpty
          ? true
          : status == normalizedStatusFilter;
      final queryMatches = query.isEmpty ||
          hall.contains(query) ||
          eventType.contains(query) ||
          bookingDate.contains(query) ||
          guestCount.contains(query) ||
          status.contains(query);
      return statusMatches && queryMatches;
    }).toList();

    filtered.sort((a, b) {
      switch (_bookingSortBy) {
        case 'newest':
          return (b['created_at']?.toString() ?? '')
              .compareTo(a['created_at']?.toString() ?? '');
        case 'oldest':
          return (a['created_at']?.toString() ?? '')
              .compareTo(b['created_at']?.toString() ?? '');
        case 'hall':
          return (a['hall_name']?.toString().toLowerCase() ?? '')
              .compareTo(b['hall_name']?.toString().toLowerCase() ?? '');
        case 'guest_count':
          final aGuests = int.tryParse(a['guest_count']?.toString() ?? '') ?? 0;
          final bGuests = int.tryParse(b['guest_count']?.toString() ?? '') ?? 0;
          return bGuests.compareTo(aGuests);
        case 'status':
          return (a['status']?.toString().toLowerCase() ?? '')
              .compareTo(b['status']?.toString().toLowerCase() ?? '');
        case 'event_date':
        default:
          return (a['booking_date']?.toString() ?? '')
              .compareTo(b['booking_date']?.toString() ?? '');
      }
    });

    return filtered;
  }

  void _clearBookingFilters() {
    _bookingSearchController.clear();
    setState(() {
      _bookingFilter = 'All';
      _bookingSortBy = 'event_date';
      _selectedDay = null;
    });
  }

  String? _bookingFilterSummary() {
    final parts = <String>[];
    final query = _bookingSearchController.text.trim();
    if (query.isNotEmpty) {
      parts.add('Search: $query');
    }
    if (_bookingFilter != 'All') {
      parts.add('Status: $_bookingFilter');
    }
    if (_bookingSortBy != 'event_date') {
      parts.add(
        'Sort: ${customerBookingSortOptions[_bookingSortBy] ?? _bookingSortBy}',
      );
    }
    if (_selectedDay != null) {
      parts.add(
        'Day: ${DateFormat('yyyy-MM-dd').format(_selectedDay!)}',
      );
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.myBookings)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<dynamic>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
            }
            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 220),
                  Center(
                      child: Text(AppLocalizations.of(context)!.noBookingsYet)),
                ],
              );
            }
            final filteredBookings = _filteredBookings(bookings);
            final eventsByDay = <DateTime, List<Map<String, dynamic>>>{};
            for (final item in filteredBookings) {
              final booking = Map<String, dynamic>.from(item as Map);
              final parsedDate = DateTime.tryParse(
                booking['booking_date']?.toString() ?? '',
              );
              if (parsedDate == null) continue;
              final dayKey =
                  DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
              eventsByDay.putIfAbsent(dayKey, () => []).add(booking);
            }
            final selectedDay = _selectedDay == null
                ? null
                : DateTime(
                    _selectedDay!.year,
                    _selectedDay!.month,
                    _selectedDay!.day,
                  );
            final visibleBookings = selectedDay == null
                ? filteredBookings
                : eventsByDay[selectedDay] ?? const <Map<String, dynamic>>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextField(
                          controller: _bookingSearchController,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search my bookings',
                            hintText: 'Search by hall, event, date, status...',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: customerBookingStatusFilters.keys
                              .map(
                                (filter) => ChoiceChip(
                                  label: Text(filter),
                                  selected: _bookingFilter == filter,
                                  onSelected: (_) =>
                                      setState(() => _bookingFilter = filter),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _bookingSortBy,
                          items: customerBookingSortOptions.entries
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(
                            () => _bookingSortBy = value ?? 'event_date',
                          ),
                          decoration: const InputDecoration(labelText: 'Sort by'),
                        ),
                        if (_bookingFilterSummary() != null) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _bookingFilterSummary()!,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton.icon(
                            onPressed: _clearBookingFilters,
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('Reset booking filters'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: TableCalendar<Map<String, dynamic>>(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      eventLoader: (day) =>
                          eventsByDay[DateTime(day.year, day.month, day.day)] ??
                          const <Map<String, dynamic>>[],
                      onDaySelected: (selectedDayValue, focusedDayValue) {
                        setState(() {
                          _selectedDay = selectedDayValue;
                          _focusedDay = focusedDayValue;
                        });
                      },
                      onPageChanged: (focusedDayValue) {
                        _focusedDay = focusedDayValue;
                      },
                      calendarStyle: const CalendarStyle(
                        markerDecoration: BoxDecoration(
                          color: Color(0xFF7C2D47),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniInsightCard(
                        label: 'Visible bookings',
                        value: '${visibleBookings.length}',
                        color: const Color(0xFF7C2D47),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniInsightCard(
                        label: 'All matching',
                        value: '${filteredBookings.length}',
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visibleBookings.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('No bookings match the current filter.'),
                    ),
                  )
                else
                ...visibleBookings.map((item) {
                  final booking = Map<String, dynamic>.from(item as Map);
                  final bookingId = bookingIdFromMap(booking);
                  final isPending = booking['status'] == 'pending';
                  final adjustedCostRaw = booking['adjusted_cost'];
                  final adjustedCost = adjustedCostRaw is num
                      ? adjustedCostRaw.toDouble()
                      : double.tryParse(adjustedCostRaw?.toString() ?? '');
                  final messages = ((booking['messages'] as List?) ?? const [])
                      .map((item) => Map<String, dynamic>.from(item as Map))
                      .toList();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['hall_name']?.toString() ?? 'Hall',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${booking['booking_date']} | ${booking['event_type']} | ${booking['guest_count']} guests',
                          ),
                          if (adjustedCost != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Estimated total: Rs. ${adjustedCost.toStringAsFixed(0)}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          if ((booking['special_request']
                                  ?.toString()
                                  .isNotEmpty ??
                              false))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "Request: ${booking['special_request']}",
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          if ((booking['additional_notes']
                                  ?.toString()
                                  .isNotEmpty ??
                              false))
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Note: ${booking['additional_notes']}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Conversation',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                BookingMessagePreview(messages: messages),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Chip(
                                label: Text(
                                    booking['status']?.toString() ?? 'pending'),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => _addToCalendar(booking),
                                icon: const Icon(Icons.calendar_today_outlined),
                                tooltip:
                                    AppLocalizations.of(context)!.addToCalendar,
                              ),
                              TextButton.icon(
                                onPressed: () => _openMessages(booking),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: Text(
                                  messages.isEmpty
                                      ? 'Messages'
                                      : 'Messages (${messages.length})',
                                ),
                              ),
                              if (isPending)
                                TextButton.icon(
                                  onPressed: bookingId == null
                                      ? null
                                      : () => _cancelBooking(bookingId),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: Text(
                                      AppLocalizations.of(context)!.cancel),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CustomerProfilePage extends StatefulWidget {
  final Map<String, dynamic> user;

  const CustomerProfilePage({super.key, required this.user});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _profileImageController;
  late String _favoriteCategory;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.user['name']?.toString() ?? '');
    _phoneController =
        TextEditingController(text: widget.user['phone']?.toString() ?? '');
    _profileImageController = TextEditingController(
        text: widget.user['profile_image']?.toString() ?? '');
    _favoriteCategory = widget.user['favorite_category']?.toString() ?? 'Any';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _profileImageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = await api.updateProfile(widget.user['id'] as int, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'favorite_category': _favoriteCategory,
        'profile_image': _profileImageController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context, Map<String, dynamic>.from(data['user'] as Map));
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _favoriteCategory,
            items: const ['Any', 'Luxury', 'Outdoor', 'Indoor', 'Budget']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) =>
                setState(() => _favoriteCategory = value ?? 'Any'),
            decoration: const InputDecoration(labelText: 'Preferred category'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _profileImageController,
            decoration: const InputDecoration(labelText: 'Profile image URL'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<dynamic>> _bookingsFuture;
  late Future<List<dynamic>> _customersFuture;
  final TextEditingController _bookingSearchController =
      TextEditingController();
  String _bookingFilter = 'All';
  String _bookingSortBy = 'newest';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _bookingSearchController.dispose();
    super.dispose();
  }

  void _reload() {
    _statsFuture = api.getStats();
    _bookingsFuture = api.getAdminBookings();
    _customersFuture = api.getCustomers();
  }

  void _refreshSilently() {
    if (!mounted) {
      return;
    }
    setState(_reload);
  }

  Future<List<Map<String, dynamic>>> _loadBookingMessages(int bookingId) async {
    final bookings = await api.getAdminBookings();
    for (final item in bookings) {
      final booking = Map<String, dynamic>.from(item as Map);
      if (bookingIdFromMap(booking) == bookingId) {
        return ((booking['messages'] as List?) ?? const [])
            .map((message) => Map<String, dynamic>.from(message as Map))
            .toList();
      }
    }
    return const [];
  }

  Future<void> _logout() async {
    await clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LandingPage()),
      (_) => false,
    );
  }

  Future<void> _updateStatus(int bookingId, String status) async {
    try {
      await api.updateBookingStatus(bookingId, status);
      if (!mounted) return;
      showAppSnackBar(context, 'Booking updated.');
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  Future<void> _showSendMessageDialog(Map<String, dynamic> booking) async {
    final bookingId = bookingIdFromMap(booking);
    if (bookingId == null) {
      showAppSnackBar(context, 'Booking ID is missing.', isError: true);
      return;
    }
    final messages = ((booking['messages'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final didUpdate = await showDialog<bool>(
      context: context,
      builder: (context) => BookingMessagesDialog(
        title: 'Messages for ${booking['customer_name'] ?? 'customer'}',
        messages: messages,
        sendButtonLabel: 'Send',
        viewerRole: 'admin',
        loadMessages: () => _loadBookingMessages(bookingId),
        onSend: (message) async {
          await api.sendBookingMessage(
            bookingId,
            message,
          );
        },
      ),
    );
    if (didUpdate == true && mounted) {
      showAppSnackBar(context, 'Message sent.');
      setState(_reload);
    }
  }

  Future<void> _openManageHalls() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageHallsPage()),
    );
    if (mounted) {
      setState(_reload);
    }
  }

  List<Map<String, dynamic>> _filteredBookings(List<dynamic> rawBookings) {
    final query = _bookingSearchController.text.trim().toLowerCase();
    final normalizedStatusFilter = adminBookingStatusFilters[_bookingFilter] ?? '';
    final filtered = rawBookings
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((booking) {
      final status = booking['status']?.toString().toLowerCase() ?? '';
      final hall = booking['hall_name']?.toString().toLowerCase() ?? '';
      final customer = booking['customer_name']?.toString().toLowerCase() ?? '';
      final eventType = booking['event_type']?.toString().toLowerCase() ?? '';
      final customerEmail =
          booking['customer_email']?.toString().toLowerCase() ?? '';
      final bookingDate = booking['booking_date']?.toString().toLowerCase() ?? '';
      final guestCount = booking['guest_count']?.toString().toLowerCase() ?? '';

      final statusMatches = normalizedStatusFilter.isEmpty
          ? true
          : status == normalizedStatusFilter;
      final queryMatches = query.isEmpty ||
          hall.contains(query) ||
          customer.contains(query) ||
          eventType.contains(query) ||
          customerEmail.contains(query) ||
          bookingDate.contains(query) ||
          guestCount.contains(query) ||
          status.contains(query);
      return statusMatches && queryMatches;
    }).toList();

    filtered.sort((a, b) {
      switch (_bookingSortBy) {
        case 'oldest':
          return (a['created_at']?.toString() ?? '')
              .compareTo(b['created_at']?.toString() ?? '');
        case 'event_date':
          return (a['booking_date']?.toString() ?? '')
              .compareTo(b['booking_date']?.toString() ?? '');
        case 'hall':
          return (a['hall_name']?.toString().toLowerCase() ?? '')
              .compareTo(b['hall_name']?.toString().toLowerCase() ?? '');
        case 'customer':
          return (a['customer_name']?.toString().toLowerCase() ?? '')
              .compareTo(b['customer_name']?.toString().toLowerCase() ?? '');
        case 'guest_count':
          final aGuests =
              int.tryParse(a['guest_count']?.toString() ?? '') ?? 0;
          final bGuests =
              int.tryParse(b['guest_count']?.toString() ?? '') ?? 0;
          return bGuests.compareTo(aGuests);
        case 'status':
          return (a['status']?.toString().toLowerCase() ?? '')
              .compareTo(b['status']?.toString().toLowerCase() ?? '');
        case 'newest':
        default:
          return (b['created_at']?.toString() ?? '')
              .compareTo(a['created_at']?.toString() ?? '');
      }
    });

    return filtered;
  }

  void _clearBookingFilters() {
    _bookingSearchController.clear();
    setState(() {
      _bookingFilter = 'All';
      _bookingSortBy = 'newest';
    });
  }

  String? _bookingFilterSummary() {
    final parts = <String>[];
    final query = _bookingSearchController.text.trim();
    if (query.isNotEmpty) {
      parts.add('Search: $query');
    }
    if (_bookingFilter != 'All') {
      parts.add('Status: $_bookingFilter');
    }
    if (_bookingSortBy != 'newest') {
      parts.add(
        'Sort: ${adminBookingSortOptions[_bookingSortBy] ?? _bookingSortBy}',
      );
    }
    if (parts.isEmpty) {
      return null;
    }
    return parts.join('  •  ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Command Center'), actions: [
        IconButton(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: _openManageHalls,
          icon: const Icon(Icons.store_mall_directory),
        ),
        IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<Map<String, dynamic>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F2937), Color(0xFF7C2D47)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 22,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.dashboard_customize_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Operations Snapshot',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Manage halls, triage booking requests, and track customer activity in one place.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.84,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _DashboardMetricCard(
                                label: 'Total halls',
                                value: '${stats['total_halls'] ?? 0}',
                                icon: Icons.apartment_outlined,
                              ),
                              _DashboardMetricCard(
                                label: 'Customers',
                                value: '${stats['total_customers'] ?? 0}',
                                icon: Icons.groups_2_outlined,
                              ),
                              _DashboardMetricCard(
                                label: 'All bookings',
                                value: '${stats['total_bookings'] ?? 0}',
                                icon: Icons.event_note_outlined,
                              ),
                              _DashboardMetricCard(
                                label: 'Pending review',
                                value: '${stats['pending_bookings'] ?? 0}',
                                icon: Icons.pending_actions_outlined,
                                highlight: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: _openManageHalls,
                                icon: const Icon(Icons.storefront_outlined),
                                label: const Text('Manage halls'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => setState(_reload),
                                icon: const Icon(Icons.sync_outlined),
                                label: const Text('Refresh data'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),
            const _AdminSectionHeader(
              title: 'Booking Queue',
              subtitle:
                  'Prioritize pending approvals and search by hall, customer, or event.',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextField(
                      controller: _bookingSearchController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search bookings',
                        hintText:
                            'Search by hall, customer, email, date, status...',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: adminBookingStatusFilters.keys
                          .map(
                            (filter) => ChoiceChip(
                              label: Text(filter),
                              selected: _bookingFilter == filter,
                              onSelected: (_) =>
                                  setState(() => _bookingFilter = filter),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _bookingSortBy,
                      items: adminBookingSortOptions.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(
                        () => _bookingSortBy = value ?? 'newest',
                      ),
                      decoration: const InputDecoration(labelText: 'Sort by'),
                    ),
                    if (_bookingFilterSummary() != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _bookingFilterSummary()!,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _clearBookingFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Reset booking filters'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final bookings = snapshot.data ?? [];
                final filteredBookings = _filteredBookings(bookings);
                final pendingCount = bookings.where((item) {
                  final booking = Map<String, dynamic>.from(item as Map);
                  return booking['status'] == 'pending';
                }).length;
                if (bookings.isEmpty) {
                  return const Text('No bookings submitted yet.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _MiniInsightCard(
                            label: 'Visible bookings',
                            value: '${filteredBookings.length}',
                            color: const Color(0xFF7C2D47),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MiniInsightCard(
                            label: 'Pending approvals',
                            value: '$pendingCount',
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (filteredBookings.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text('No bookings match the current filter.'),
                        ),
                      )
                    else
                      ...filteredBookings.map((booking) {
                        final status =
                            booking['status']?.toString() ?? 'pending';
                        final bookingId = bookingIdFromMap(booking);
                        final isPending = status == 'pending';
                        final messages =
                            ((booking['messages'] as List?) ?? const [])
                                .map((item) =>
                                    Map<String, dynamic>.from(item as Map))
                                .toList();
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: BorderSide(
                              color: isPending
                                  ? const Color(0xFF7C2D47)
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            booking['hall_name']?.toString() ??
                                                'Hall',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${booking['customer_name']} | ${booking['booking_date']}',
                                          ),
                                          Text(
                                            '${booking['event_type']} | ${booking['guest_count']} guests',
                                          ),
                                        ],
                                      ),
                                    ),
                                    _StatusBadge(status: status),
                                  ],
                                ),
                                if ((booking['special_request']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                    false))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFFFF),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        'Special request: ${booking['special_request']}',
                                      ),
                                    ),
                                  ),
                                if ((booking['additional_notes']
                                        ?.toString()
                                        .trim()
                                        .isNotEmpty ??
                                    false))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECECEC),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        "Notes: ${booking['additional_notes']}",
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECECEC),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Conversation',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      BookingMessagePreview(messages: messages),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton(
                                      onPressed: isPending
                                          && bookingId != null
                                          ? () => _updateStatus(
                                                bookingId,
                                                'approved',
                                              )
                                          : null,
                                      child: const Text('Approve'),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: isPending
                                          && bookingId != null
                                          ? () => _updateStatus(
                                                bookingId,
                                                'rejected',
                                              )
                                          : null,
                                      child: const Text('Reject'),
                                    ),
                                    FilledButton.tonal(
                                      onPressed: () =>
                                          _showSendMessageDialog(booking),
                                      child: Text(
                                        messages.isEmpty
                                            ? 'Message'
                                            : 'Message (${messages.length})',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            const _AdminSectionHeader(
              title: 'Customer Intelligence',
              subtitle:
                  'See who registered recently and which categories they prefer.',
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<dynamic>>(
              future: _customersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = snapshot.data ?? [];
                final customerMaps = customers
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
                final categoryCounts = <String, int>{};
                for (final customer in customerMaps) {
                  final category =
                      customer['favorite_category']?.toString() ?? 'Any';
                  categoryCounts[category] =
                      (categoryCounts[category] ?? 0) + 1;
                }
                final rankedCategories = categoryCounts.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));

                return Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preference trends',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: rankedCategories.isEmpty
                                  ? [const Chip(label: Text('No data yet'))]
                                  : rankedCategories
                                      .take(5)
                                      .map(
                                        (entry) => Chip(
                                          label: Text(
                                            '${entry.key}: ${entry.value}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...customerMaps.take(8).map((customer) {
                      final profileImage =
                          customer['profile_image']?.toString() ?? '';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: profileImage.isNotEmpty
                                ? NetworkImage(profileImage)
                                : null,
                            child: profileImage.isEmpty
                                ? const Icon(Icons.person_outline)
                                : null,
                          ),
                          title: Text(customer['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${customer['email'] ?? ''}\n${customer['phone'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECECEC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              customer['favorite_category']?.toString() ??
                                  'Any',
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ManageHallsPage extends StatefulWidget {
  const ManageHallsPage({super.key});

  @override
  State<ManageHallsPage> createState() => _ManageHallsPageState();
}

class _ManageHallsPageState extends State<ManageHallsPage> {
  late Future<List<dynamic>> _hallsFuture;

  @override
  void initState() {
    super.initState();
    _hallsFuture = api.getHalls();
  }

  void _refresh() {
    setState(() => _hallsFuture = api.getHalls());
  }

  Future<void> _showHallForm([Map<String, dynamic>? hall]) async {
    final nameController =
        TextEditingController(text: hall?['name']?.toString() ?? '');
    final locationController =
        TextEditingController(text: hall?['location']?.toString() ?? '');
    final capacityController =
        TextEditingController(text: hall?['capacity']?.toString() ?? '');
    final rentController =
        TextEditingController(text: hall?['rent']?.toString() ?? '');
    final contactController =
        TextEditingController(text: hall?['contact_person']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: hall?['phone_number']?.toString() ?? '');
    final emailController =
        TextEditingController(text: hall?['email']?.toString() ?? '');
    final descriptionController =
        TextEditingController(text: hall?['description']?.toString() ?? '');
    final imageUrlsController = TextEditingController(
      text: (hall?['image_urls'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .join(', '),
    );
    String category = hall?['category']?.toString() ?? 'Indoor';
    bool isFeatured = hall?['is_featured'] as bool? ?? false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(hall == null ? 'Add hall' : 'Edit hall'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  TextField(
                    controller: capacityController,
                    decoration: const InputDecoration(labelText: 'Capacity'),
                  ),
                  TextField(
                    controller: rentController,
                    decoration: const InputDecoration(labelText: 'Rent'),
                  ),
                  TextField(
                    controller: contactController,
                    decoration:
                        const InputDecoration(labelText: 'Contact person'),
                  ),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  TextField(
                    controller: imageUrlsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Image asset paths or URLs',
                      helperText: 'Use comma separated values.',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    items: hallCategories
                        .where((item) => item != 'All')
                        .map((item) =>
                            DropdownMenuItem(value: item, child: Text(item)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? 'Indoor'),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  SwitchListTile(
                    value: isFeatured,
                    title: const Text('Featured hall'),
                    onChanged: (value) =>
                        setDialogState(() => isFeatured = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final payload = {
                    'name': nameController.text.trim(),
                    'location': locationController.text.trim(),
                    'capacity':
                        int.tryParse(capacityController.text.trim()) ?? 100,
                    'rent': double.tryParse(rentController.text.trim()) ?? 0,
                    'contact_person': contactController.text.trim(),
                    'phone_number': phoneController.text.trim(),
                    'email': emailController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'image_urls': imageUrlsController.text
                        .split(',')
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(),
                    'category': category,
                    'is_featured': isFeatured,
                  };

                  try {
                    if (hall == null) {
                      await api.addHall(payload);
                    } else {
                      await api.updateHall(hall['hall_id'] as int, payload);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _refresh();
                  } catch (error) {
                    if (!context.mounted) return;
                    showAppSnackBar(context, error.toString(), isError: true);
                  }
                },
                child: Text(hall == null ? 'Create' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteHall(int hallId) async {
    try {
      await api.deleteHall(hallId);
      if (!mounted) return;
      _refresh();
      showAppSnackBar(context, 'Hall deleted.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, error.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Halls')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHallForm(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _hallsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final halls = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: halls.map((item) {
              final hall = Map<String, dynamic>.from(item as Map);
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: buildHallImage(
                      hallPrimaryImage(hall),
                      height: 56,
                      width: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(hall['name']?.toString() ?? ''),
                  subtitle: Text('${hall['location']} | Rs. ${hall['rent']}'),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        onPressed: () => _showHallForm(hall),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deleteHall(hall['hall_id'] as int),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class HallPreviewCard extends StatelessWidget {
  final Map<String, dynamic> hall;
  final VoidCallback onTap;

  const HallPreviewCard({super.key, required this.hall, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gallery = hallImagesFor(hall);
    final imagePath = gallery.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                buildHallImage(
                  imagePath,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.62),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hall['name']?.toString() ?? '',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${hall['location']} | ${hall['category']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Rs. ${hall['rent']}',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _previewChip(
                        context,
                        Icons.groups_2_outlined,
                        '${hall['capacity']} guests',
                      ),
                      _previewChip(
                        context,
                        Icons.photo_library_outlined,
                        '${gallery.length} photos',
                      ),
                      if (hall['distance_km'] != null)
                        _previewChip(
                          context,
                          Icons.near_me_outlined,
                          '${hall['distance_km']} km away',
                        ),
                      if ((hall['feedback_count'] as num? ?? 0) > 0)
                        _previewChip(
                          context,
                          Icons.star_rounded,
                          '${hall['average_rating']} (${hall['feedback_count']})',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: buildHallImage(
                          gallery[index],
                          height: 72,
                          width: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewChip(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECE8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF7C2D47)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: highlight
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 18),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AdminSectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }
}

class _MiniInsightCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniInsightCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    switch (status) {
      case 'approved':
        background = const Color(0xFFE3F4E8);
        foreground = const Color(0xFF1D6B37);
        break;
      case 'rejected':
        background = const Color(0xFFECECEC);
        foreground = const Color(0xFF9D2235);
        break;
      case 'cancelled':
        background = const Color(0xFFF1F1F1);
        foreground = const Color(0xFF555555);
        break;
      default:
        background = const Color(0xFFECECEC);
        foreground = const Color(0xFF7C2D47);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
