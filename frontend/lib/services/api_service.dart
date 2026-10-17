import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  /// Base API URL.
  /// Android emulator connects to the host machine via 10.0.2.2.
  /// iOS simulator, Desktop, and Web connect via localhost.
  static String get defaultBaseUrl {
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