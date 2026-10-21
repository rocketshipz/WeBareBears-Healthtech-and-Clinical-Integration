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
        final token =
            data['data']?['token'] ?? data['token'] ?? data['access_token'];
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

  /// Request a 6-digit Email verification code.
  ///
  /// Sends a POST request to `/auth/send-code`.
  static Future<Map<String, dynamic>> sendVerificationCode({
    required String email,
    required String phone,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/send-code');

    try {
      final response = await http
          .post(
            url,
            headers: ApiService.defaultHeaders,
            body: jsonEncode({
              'email': email.trim().toLowerCase(),
              'phone': phone.trim(),
            }),
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
    required String phone,
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
              'phone': phone.trim(),
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
    required String name,
    required String sexAtBirth,
    required String nationality,
    DateTime? dateOfBirth,
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
      payload['name'] = name.trim();
      payload['sex_at_birth'] = sexAtBirth;
      payload['nationality'] = nationality;
      if (dateOfBirth != null) {
        payload['date_of_birth'] = dateOfBirth
            .toIso8601String()
            .split('T')
            .first;
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

        final token =
            data['data']?['token'] ?? data['token'] ?? data['access_token'];
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

  /// Request a 6-digit password reset code for the account registered to [email].
  ///
  /// Sends a POST request to `/auth/forgot-password`. The backend answers the same
  /// way whether or not the email is registered.
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) => _postPasswordReset('forgot-password', {
    'email': email.trim().toLowerCase(),
  });

  /// Check a password reset code before asking for the new password.
  ///
  /// Sends a POST request to `/auth/verify-reset-code`.
  static Future<Map<String, dynamic>> verifyResetCode({
    required String email,
    required String code,
  }) => _postPasswordReset('verify-reset-code', {
    'email': email.trim().toLowerCase(),
    'code': code.trim(),
  });

  /// Set a new password using a verified reset code.
  ///
  /// Sends a POST request to `/auth/reset-password`.
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _postPasswordReset('reset-password', {
    'email': email.trim().toLowerCase(),
    'code': code.trim(),
    'new_password': newPassword,
  });

  static Future<Map<String, dynamic>> _postPasswordReset(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiService.baseUrl}/auth/$path');
    try {
      final response = await http
          .post(url, headers: ApiService.defaultHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw AuthException(
        _parseErrorMessage(response),
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw AuthException(
        'Unable to connect to the server. Please check your network or server status.',
      );
    } on TimeoutException {
      throw AuthException('Connection timed out. Please try again.');
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Password reset failed: $e');
    }
  }

  static Future<Map<String, dynamic>> loadProfile() => _profileRequest();

  static Future<Map<String, dynamic>> saveProfile(
    Map<String, dynamic> values,
  ) => _profileRequest(values);

  static Future<Map<String, dynamic>> _profileRequest([
    Map<String, dynamic>? values,
  ]) async {
    if (!isAuthenticated) {
      throw AuthException('Please log in to save your profile.');
    }
    final uri = Uri.parse('${ApiService.baseUrl}/auth/profile');
    try {
      final response =
          await (values == null
                  ? http.get(uri, headers: ApiService.defaultHeaders)
                  : http.put(
                      uri,
                      headers: ApiService.defaultHeaders,
                      body: jsonEncode(values),
                    ))
              .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _parseErrorMessage(response),
          statusCode: response.statusCode,
        );
      }
      final result = jsonDecode(response.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(result['data'] as Map);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException(
        'Could not save or load your profile. Please try again.',
      );
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
