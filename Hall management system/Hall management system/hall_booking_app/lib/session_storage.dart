import 'session_storage_stub.dart'
    if (dart.library.html) 'session_storage_web.dart' as storage;

Future<String?> readSessionValue(String key) => storage.readSessionValue(key);

Future<void> writeSessionValue(String key, String value) =>
    storage.writeSessionValue(key, value);

Future<void> removeSessionValue(String key) => storage.removeSessionValue(key);
