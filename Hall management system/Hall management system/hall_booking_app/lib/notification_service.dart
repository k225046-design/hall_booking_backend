import 'dart:async';
import 'package:flutter/foundation.dart';
import 'message_model.dart';

class NotificationService {
  static StreamController<List<Message>> _controller = StreamController<List<Message>>.broadcast();
  static Stream<List<Message>> get messagesStream => _controller.stream;

  static void initialize() {
    // Stub implementation - polling or websocket would go here
  }

  static void addMessage(Message message) {
    // Stub
  }
}
