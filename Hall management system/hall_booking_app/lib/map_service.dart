import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class MapService {
  static LatLng? getHallLocation(String city) {
    // Simplified coordinates matching backend CITY_COORDINATES
    const coordinates = {
      'karachi': LatLng(24.8607, 67.0011),
      'lahore': LatLng(31.5204, 74.3587),
      'islamabad': LatLng(33.6844, 73.0479),
      'faisalabad': LatLng(31.4504, 73.1350),
      'multan': LatLng(30.1575, 71.5249),
    };
    return coordinates[city.toLowerCase()];
  }

  static double calculateDistance(LatLng hallPos, LatLng userPos) {
    const earthRadius = 6371000; // meters
    final dLat = (hallPos.latitude - userPos.latitude).toRadians();
    final dLon = (hallPos.longitude - userPos.longitude).toRadians();
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userPos.latitude.toRadians()) * cos(hallPos.latitude.toRadians()) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c / 1000; // km
  }

  static Set<Marker> createHallMarkers(List<Map<String, dynamic>> halls) {
    return halls.map((hall) {
      final pos = getHallLocation(hall['location'] ?? '');
      if (pos == null) return null;
      return Marker(
        markerId: MarkerId(hall['hall_id'].toString()),
        position: pos,
        infoWindow: InfoWindow(title: hall['name'], snippet: hall['location']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );
    }).whereType<Marker>().toSet();
  }
}

extension Rad on num {
  num toRadians() => this * pi / 180;
}

