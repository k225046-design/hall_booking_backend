// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<String?> readSessionValue(String key) async =>
    html.window.localStorage[key];

Future<void> writeSessionValue(String key, String value) async {
  html.window.localStorage[key] = value;
}

Future<void> removeSessionValue(String key) async {
  html.window.localStorage.remove(key);
}
