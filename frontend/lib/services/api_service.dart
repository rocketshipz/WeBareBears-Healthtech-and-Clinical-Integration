import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  /// Deployed backend, set at build time:
  /// `flutter build web --dart-define=API_BASE_URL=https://api.example.com/api`
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  /// Base API URL.
  /// Without API_BASE_URL (local development):
  /// Android emulator connects to the host machine via 10.0.2.2.
  /// iOS simulator, Desktop, and Web connect via localhost.
  static String get defaultBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) return _apiBaseUrlOverride;
    if (kIsWeb) return 'http://localhost:8000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api';
    } catch (_) {
      // Fallback if Platform is unsupported
    }
    return 'http://localhost:8000/api';
  }

  static String baseUrl = defaultBaseUrl;

  /// Stored bearer token for authenticated requests
  static String? authToken;

  /// Default headers sent with JSON requests
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };
}