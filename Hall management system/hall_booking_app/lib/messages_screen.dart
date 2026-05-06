import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'message_model.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatefulWidget {
  final int userId;
  final String userRole;

  const MessagesScreen({
    super.key,
    required this.userId,
    required this.userRole,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Message> _messages = [];
  List<Message> _filteredMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _searchController.addListener(_filterMessages);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    NotificationService.fetchAllMessages(widget.userId).then((_) {
      if (mounted) setState(() => _isLoading = false);
    });
    _searchController.addListener(_filterMessages);
  }

  Future<void> _refreshMessages() async {
    await NotificationService.fetchAllMessages(widget.userId);
  }

  void _filterMessages() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMessages = _messages.where((msg) {
        return msg.text.toLowerCase().contains(query) ||
            msg.senderName.toLowerCase().contains(query) ||
            (msg.hallName?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _markAsRead(Message message) async {
    if (message.id == null || message.isRead) return;
    try {
      await http.put(
        Uri.parse('$baseUrl/message/${message.id}/read'),
        headers: {'Content-Type': 'application/json'},
      );
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = Message(
            id: message.id,
            text: message.text,
            senderName: message.senderName,
            senderRole: message.senderRole,
            timestamp: message.timestamp,
            bookingId: message.bookingId,
            isRead: true,
            hallName: message.hallName,
          );
        }
        _filterMessages();
      });
    } catch (e) {
      debugPrint('Mark read failed: $e');
    }
  }

  int get _unreadCount => _messages.where((m) => !m.isRead).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages ($_unreadCount unread)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search messages',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMessages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Check back later.'),
                      )
                    : ListView.builder(
                        itemCount: _filteredMessages.length,
                        itemBuilder: (context, index) {
                          final message = _filteredMessages[index];
                          final isUnread = !message.isRead;
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            color: isUnread ? Colors.blue.shade50 : null,
                            child: ListTile(
                              onTap: () => _markAsRead(message),
                              leading: CircleAvatar(
                                backgroundColor: isUnread
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade200,
                                child: Text(
                                  message.senderName.isNotEmpty
                                      ? message.senderName[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              title: Text(
                                message.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(message.senderName),
                                  if (message.hallName != null)
                                    Text(
                                      message.hallName!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  if (message.bookingId != null)
                                    Text(
                                      'Booking #${message.bookingId}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: isUnread
                                  ? const Icon(
                                      Icons.circle,
                                      color: Colors.blue,
                                      size: 12,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Compose Message'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'To'),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Subject'),
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Message'),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // TODO: Send message
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message sent!')),
                    );
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

