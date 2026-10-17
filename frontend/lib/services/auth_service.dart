import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Custom exception for authentication errors.
class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthService {
  static String? _token;
  static Map<String, dynamic>? _currentUser;

  /// Stored token from successful login/register
  static String? get token => _token;

  /// Cached user profile info
  static Map<String, dynamic>? get currentUser => _currentUser;

  /// Returns true if a valid session token is stored
  static bool get isAuthenticated => _token != null;

  /// Authenticate an existing user with email, phone number, or IC and password.
  ///
  /// Sends a POST request to `/auth/login`.
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/login');

    try {
      final response = await http
          .post(
            url,
            headers: ApiService.defaultHeaders,
            body: jsonEncode({
              'identifier': identifier.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Extract token and user if returned by backend
        final token = data['data']?['token'] ?? data['token'] ?? data['access_token'];
        if (token != null) {
          _token = token.toString();
          ApiService.authToken = _token;
        }

        final user = data['data']?['user'] ?? data['user'];
        if (user is Map<String, dynamic>) {
          _currentUser = user;
        }

        return data;
      } else {
        throw AuthException(
          _parseErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AuthException(
        'Unable to connect to the server. Please check your network or server status.',
      );
    } on TimeoutException {
      throw AuthException('Connection timed out. Please try again.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Unexpected error during login: $e');
    }
  }

  /// Request a 6-digit email verification code.
  ///
  /// Sends a POST request to `/auth/send-code`.
  static Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/send-code');

    try {
      final response = await http
          .post(
            url,
            headers: ApiService.defaultHeaders,
            body: jsonEncode({'email': email.trim().toLowerCase()}),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw AuthException(
          _parseErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AuthException(
        'Unable to reach server to send verification code. Please check your network.',
      );
    } on TimeoutException {
      throw AuthException('Email verification request timed out.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to send verification code: $e');
    }
  }

  /// Verify the 6-digit code sent to the email address.
  ///
  /// Sends a POST request to `/auth/verify-code`.
  static Future<bool> verifyCode({
    required String email,
    required String code,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/verify-code');

    try {
      final response = await http
          .post(
            url,
            headers: ApiService.defaultHeaders,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'code': code.trim(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        throw AuthException(
          _parseErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AuthException(
        'Unable to reach server to verify code. Please check your network.',
      );
    } on TimeoutException {
      throw AuthException('Code verification timed out.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Failed to verify code: $e');
    }
  }

  /// Register a new user account with IC, phone, verified email, and password.
  ///
  /// Sends a POST request to `/auth/register`.
  static Future<Map<String, dynamic>> register({
    required String ic,
    required String phone,
    required String email,
    required String password,
    String? code,
    String? name,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/register');

    try {
      final payload = <String, dynamic>{
        'ic': ic.trim(),
        'phone': phone.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      };
      if (code != null && code.trim().isNotEmpty) {
        payload['code'] = code.trim();
      }
      if (name != null && name.trim().isNotEmpty) {
        payload['name'] = name.trim();
      }

      final response = await http
          .post(
            url,
            headers: ApiService.defaultHeaders,
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final token = data['data']?['token'] ?? data['token'] ?? data['access_token'];
        if (token != null) {
          _token = token.toString();
          ApiService.authToken = _token;
        }

        final user = data['data']?['user'] ?? data['user'];
        if (user is Map<String, dynamic>) {
          _currentUser = user;
        }

        return data;
      } else {
        throw AuthException(
          _parseErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AuthException(
        'Unable to connect to the server. Please check your network or server status.',
      );
    } on TimeoutException {
      throw AuthException('Connection timed out. Please try again.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Unexpected error during registration: $e');
    }
  }

  /// Clear the active user session and auth token.
  static void logout() {
    _token = null;
    _currentUser = null;
    ApiService.authToken = null;
  }

  /// Helper to extract clean error messages from API responses.
  static String _parseErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] != null) {
          final detail = decoded['detail'];
          if (detail is String) return detail;
          if (detail is List && detail.isNotEmpty) {
            return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
          }
        }
        if (decoded['message'] != null) return decoded['message'].toString();
        if (decoded['error'] != null) return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Authentication error (Status code: ${response.statusCode})';
  }
}