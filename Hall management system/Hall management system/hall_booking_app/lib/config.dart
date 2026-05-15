import 'package:flutter/foundation.dart';

String get baseUrl {
  const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  if (configuredBaseUrl.isNotEmpty) {
    return configuredBaseUrl;
  }

  return 'https://Hallbooking.pythonanywhere.com';
}