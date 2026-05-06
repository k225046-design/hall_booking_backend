class Message {
  final String id;
  final String bookingId;
  final String senderRole;
  final String senderName;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.bookingId,
    required this.senderRole,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['message_id']?.toString() ?? '',
      bookingId: json['booking_id']?.toString() ?? '',
      senderRole: json['sender_role']?.toString() ?? '',
      senderName: json['sender_name']?.toString() ?? '',
      content: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
