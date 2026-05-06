import 'package:flutter/material.dart';
import 'main.dart'; // for api, etc.

class MessagesScreen extends StatelessWidget {
  final int userId;
  final String userRole;

  const MessagesScreen({super.key, required this.userId, required this.userRole});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: const Center(
        child: Text('Messages functionality\n(Real-time via polling/SSE/WebSocket stubbed)'),
      ),
    );
  }
}
