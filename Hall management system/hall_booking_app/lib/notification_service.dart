import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'message_model.dart';
import 'package:rxdart/rxdart.dart';

class NotificationService {
  static FirebaseMessaging? _messaging;
  static final BehaviorSubject<List<Message>> _messagesSubject = BehaviorSubject.seeded(const []);  
  static Stream<List<Message>> get messagesStream => _messagesSubject.stream;
  static List<Message> get currentMessages => _messagesSubject.valueOrNull ?? [];

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    _messaging = FirebaseMessaging.instance;

    // Request permission
    NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User permission: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _messaging!.getToken();
    debugPrint('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.notification?.title}');
      final newMessage = Message.fromFCM(message);
      final current = List<Message>.from(_messagesSubject.valueOrNull ?? []);
      _messagesSubject.add([...current, newMessage]);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Opened from notification: ${message.notification?.title}');
      // Navigate to booking page
    });
  }

  static Future<void> registerFCMToken(int customerId, String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/customer/fcm-token/$customerId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      );
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  static Future<List<Message>> fetchAllMessages(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/customer/messages/$userId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final messages = data.map((json) => Message.fromJson(json)).toList();
        _messagesSubject.add(messages);
        return messages;
      }
    } catch (e) {
      debugPrint('Fetch messages failed: $e');
    }
    return [];
  }

  static Future<void> markAsRead(int messageId) async {
    try {
      await http.put(
        Uri.parse('$baseUrl/message/$messageId/read'),
        headers: {'Content-Type': 'application/json'},
      );
      final current = List<Message>.from(_messagesSubject.valueOrNull ?? []);
      final updated = current.map((m) {
        if (m.id == messageId) {
          return Message(
            id: m.id,
            text: m.text,
            senderName: m.senderName,
            senderRole: m.senderRole,
            timestamp: m.timestamp,
            bookingId: m.bookingId,
            isRead: true,
            hallName: m.hallName,
          );
        }
        return m;
      }).toList();
      _messagesSubject.add(updated);
    } catch (e) {
      debugPrint('Mark read failed: $e');
    }
  }

  static Future<void> sendBookingNotification({
    required String title,
    required String body,
    required List<String> tokens,
  }) async {
    // Server-side call (admin sends via backend)
    debugPrint('Sending notification: $title');
  }
}

