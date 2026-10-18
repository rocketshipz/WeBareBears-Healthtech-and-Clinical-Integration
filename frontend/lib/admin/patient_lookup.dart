import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/api_service.dart';

class PatientLookup {
  static String? token;

  static Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final response =
        await (body == null
                ? http.get(url, headers: headers)
                : http.post(url, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 20));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(
        data['detail'] is String ? data['detail'] : 'Request failed.',
      );
    }
    return data;
  }
}
