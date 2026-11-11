import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Máy ảo Android gọi máy tính qua 10.0.2.2. Đổi số cổng thành cổng "http"
// trong RentMate.Api/Properties/launchSettings.json.
const String apiBaseUrl = 'http://10.0.2.2:5076';

class AuthService {
  static const _tokenKey = 'token';
  static const _nameKey = 'fullName';

  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) throw Exception(_errorMessage(res));

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token'] as String);
    await prefs.setString(_nameKey, (data['fullName'] ?? '') as String);
  }

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(_errorMessage(res));
    }
  }

  Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<String?> getFullName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
  }

  // API có thể trả {message}, ProblemDetails {title, detail} hoặc lỗi validation {errors}.
  String _errorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        if (body['message'] != null) return body['message'].toString();
        final errors = body['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          return first is List ? first.first.toString() : first.toString();
        }
        if (body['detail'] != null) return body['detail'].toString();
        if (body['title'] != null) return body['title'].toString();
      }
      if (body is String && body.isNotEmpty) return body;
    } catch (_) {
      if (res.body.isNotEmpty) return res.body;
    }
    return 'Lỗi ${res.statusCode}';
  }
}
