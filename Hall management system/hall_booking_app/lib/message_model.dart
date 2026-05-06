import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class Message {
  final int? id;
  final String text;
  final String senderName;
  final String senderRole; // 'admin' or 'customer'
  final String? timestamp;
  final int? bookingId;
  final bool isRead;
  final String? hallName;

  const Message({
    this.id,
    required this.text,
    required this.senderName,
    required this.senderRole,
    this.timestamp,
    this.bookingId,
    this.isRead = false,
    this.hallName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int?,
      text: json['message']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? 'Unknown',
      senderRole: json['sender_role']?.toString() ?? 'unknown',
      timestamp: json['created_at']?.toString(),
      bookingId: json['booking_id'] as int?,
      isRead: json['is_read'] == true,
      hallName: json['hall_name']?.toString(),
    );
  }

  factory Message.fromFCM(RemoteMessage message) {
    final data = message.data;
    return Message(
      text: message.notification?.body ?? data['message'] ?? 'New message',
      senderName: data['sender_name'] ?? 'Admin',
      senderRole: data['sender_role'] ?? 'admin',
      timestamp: data['timestamp'],
      bookingId: int.tryParse(data['booking_id'] ?? ''),
      hallName: data['hall_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': text,
    'sender_name': senderName,
    'sender_role': senderRole,
    'created_at': timestamp,
    'booking_id': bookingId,
    'is_read': isRead,
    'hall_name': hallName,
  };

  @override
  String toString() => 'Message(id: $id, text: $text, from: $senderName, read: $isRead)';
}

