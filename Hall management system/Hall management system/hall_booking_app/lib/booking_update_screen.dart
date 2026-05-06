import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_service.dart';

class BookingUpdateScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  final Function(Map<String, dynamic>) onUpdated;

  const BookingUpdateScreen({
    super.key,
    required this.booking,
    required this.onUpdated,
  });

  @override
  State<BookingUpdateScreen> createState() => _BookingUpdateScreenState();
}

class _BookingUpdateScreenState extends State<BookingUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();
  int _guestCount = 100;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.booking['booking_date']);
    _guestCount = widget.booking['guest_count'];
  }

  Future<void> _requestCancel() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final result = await BookingService.requestCancel(
        widget.booking['hall_booking_id'],
        widget.booking['customer_id'],
        _reasonController.text,
      );
      widget.onUpdated(result['booking']);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateDate() async {
    try {
      final result = await BookingService.updateDate(
        widget.booking['hall_booking_id'],
        widget.booking['customer_id'],
        _selectedDate.toIso8601String().split('T')[0],
      );
      widget.onUpdated(result['booking']);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateGuests() async {
    try {
      final result = await BookingService.updateGuests(
        widget.booking['hall_booking_id'],
        widget.booking['customer_id'],
        _guestCount,
      );
      widget.onUpdated(result['booking']);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Booking')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: const Text('Current Date'),
                subtitle: Text(widget.booking['booking_date']),
                trailing: ElevatedButton.icon(
                  onPressed: _updateDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                ),
              ),
            ),
            Card(
              child: ListTile(
                title: const Text('Current Guests'),
                subtitle: Text('${widget.booking['guest_count']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _guestCount > 10 ? () => setState(() => _guestCount--) : null,
                    ),
                    Text('$_guestCount'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => setState(() => _guestCount++),
                    ),
                    ElevatedButton(
                      onPressed: _updateGuests,
                      child: const Text('Update'),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Request Cancel (>1 week policy)', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        hintText: 'Reason for cancellation',
                        labelText: 'Reason',
                      ),
                      maxLines: 3,
                      validator: (value) => value?.isEmpty == true ? 'Reason required' : null,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _requestCancel,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('Request Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
