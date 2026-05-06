const Map<String, String> _memoryStore = <String, String>{};

Future<String?> readSessionValue(String key) async => _memoryStore[key];

Future<void> writeSessionValue(String key, String value) async {
  _memoryStore[key] = value;
}

Future<void> removeSessionValue(String key) async {
  _memoryStore.remove(key);
}
