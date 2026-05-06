import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

class CalendarService {
  static Future<void> addBookingToCalendar({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
  }) async {
    final event = Event(
      title: title,
      description: description,
      location: location,
      startDate: startDate,
      endDate: endDate,
      allDay: true,
    );

    try {
      // Try to add to native calendar first
      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      // Fallback to Google Calendar web URL
      await _addToGoogleCalendarWeb(
        title: title,
        description: description,
        startDate: startDate,
        endDate: endDate,
        location: location,
      );
    }
  }

  static Future<void> _addToGoogleCalendarWeb({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
    required String location,
  }) async {
    // Format dates for Google Calendar URL
    final startDateStr = startDate.toIso8601String().split('T')[0].replaceAll('-', '');
    final endDateStr = endDate.add(const Duration(days: 1)).toIso8601String().split('T')[0].replaceAll('-', '');

    final url = Uri.parse(
      'https://calendar.google.com/calendar/render?'
      'action=TEMPLATE&'
      'text=${Uri.encodeComponent(title)}&'
      'dates=$startDateStr/$endDateStr&'
      'details=${Uri.encodeComponent(description)}&'
      'location=${Uri.encodeComponent(location)}&'
      'sf=true&'
      'output=xml'
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch calendar URL';
    }
  }

  static Future<void> addBookingReminder({
    required String hallName,
    required DateTime bookingDate,
    required String customerName,
  }) async {
    final title = 'Hall Booking Reminder - $hallName';
    final description = 'Booking reminder for $customerName at $hallName';
    final reminderDate = bookingDate.subtract(const Duration(days: 1));

    await addBookingToCalendar(
      title: title,
      description: description,
      startDate: reminderDate,
      endDate: reminderDate,
      location: hallName,
    );
  }
}