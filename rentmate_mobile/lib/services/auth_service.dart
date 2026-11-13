import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Máy ảo Android gọi máy tính qua 10.0.2.2. Đổi số cổng thành cổng "http"
// trong RentMate.Api/Properties/launchSettings.json.
const String apiBaseUrl = 'http://10.0.2.2:5076';

// Dùng để quay về màn hình đăng nhập từ bất kỳ đâu khi phiên hết hạn.
final navigatorKey = GlobalKey<NavigatorState>();

// main.dart gán hàm này: đăng xuất rồi mở màn hình đăng nhập.
VoidCallback? onSessionExpired;

class AuthService {
  static const _tokenKey = 'token';
  static const _nameKey = 'fullName';
  static const _userIdKey = 'userId';
  static const _emailKey = 'email';

  static const _json = {'Content-Type': 'application/json'};

  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Auth/login'),
      headers: _json,
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode != 200) throw Exception(apiErrorMessage(res));
    await saveSession(jsonDecode(res.body) as Map<String, dynamic>);
  }

  // Lưu token + thông tin người dùng (dùng khi đăng nhập và khi đổi mật khẩu được cấp token mới).
  Future<void> saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, data['token'] as String);
    await prefs.setString(_nameKey, (data['fullName'] ?? '') as String);
    await prefs.setString(_userIdKey, data['userId'] as String);
    await prefs.setString(_emailKey, (data['email'] ?? '') as String);
  }

  Future<void> saveFullName(String fullName) async =>
      (await SharedPreferences.getInstance()).setString(_nameKey, fullName);

  Future<void> register({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Auth/register'),
      headers: _json,
      body: jsonEncode({
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(apiErrorMessage(res));
    }
  }

  /// Gửi mã 6 số vào email. Trả về câu thông báo của server.
  Future<String> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Auth/forgot-password'),
      headers: _json,
      body: jsonEncode({'email': email}),
    );
    if (res.statusCode != 200) throw Exception(apiErrorMessage(res));
    return apiErrorMessage(res);
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Auth/reset-password'),
      headers: _json,
      body: jsonEncode({'email': email, 'code': code, 'newPassword': newPassword}),
    );
    if (res.statusCode != 200) throw Exception(apiErrorMessage(res));
  }

  Future<String?> getToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<String?> getFullName() async =>
      (await SharedPreferences.getInstance()).getString(_nameKey);

  Future<String?> getUserId() async =>
      (await SharedPreferences.getInstance()).getString(_userIdKey);

  Future<String?> getEmail() async =>
      (await SharedPreferences.getInstance()).getString(_emailKey);

  // Header cho các API cần đăng nhập ([Authorize]).
  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    if (token == null) throw Exception('Bạn cần đăng nhập lại');
    return {..._json, 'Authorization': 'Bearer $token'};
  }

  // Header cho API không bắt buộc đăng nhập nhưng có token thì gửi kèm (vd. xem đồ của chính mình).
  Future<Map<String, String>> optionalAuthHeaders() async {
    final token = await getToken();
    return token == null ? _json : {..._json, 'Authorization': 'Bearer $token'};
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_tokenKey, _nameKey, _userIdKey, _emailKey]) {
      await prefs.remove(key);
    }
  }
}

// Ném lỗi dễ hiểu nếu API không trả 2xx.
void checkResponse(http.Response res) {
  if (res.statusCode == 401) {
    // Token hết hạn, tài khoản bị khóa hoặc mật khẩu đã đổi ở máy khác: về màn hình đăng nhập
    onSessionExpired?.call();
    throw Exception('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
  }
  if (res.statusCode == 403) throw Exception('Bạn không có quyền thực hiện thao tác này');
  if (res.statusCode == 404) throw Exception('Không tìm thấy dữ liệu, có thể đã bị xóa');
  if (res.statusCode < 200 || res.statusCode >= 300) throw Exception(apiErrorMessage(res));
}

// API có thể trả chuỗi, {message}, ProblemDetails {title, detail} hoặc lỗi validation {errors}.
String apiErrorMessage(http.Response res) {
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
