wimport 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class BookingService {

  static Future<Map<String, dynamic>> requestCancel(int bookingId, int customerId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/booking/$bookingId/request_cancel'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'customer_id': customerId,
        'reason': reason,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Cancel request failed');
  }

  static Future<Map<String, dynamic>> updateDate(int bookingId, int customerId, String newDate) async {
    final response = await http.put(
      Uri.parse('$baseUrl/booking/$bookingId/update_date'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'customer_id': customerId,
        'new_date': newDate,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Date update failed');
  }

  static Future<Map<String, dynamic>> updateGuests(int bookingId, int customerId, int newGuests) async {
    final response = await http.put(
      Uri.parse('$baseUrl/booking/$bookingId/update_guests'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'customer_id': customerId,
        'new_guest_count': newGuests,
      }),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    
    throw Exception('Guest update failed');
  }
}
