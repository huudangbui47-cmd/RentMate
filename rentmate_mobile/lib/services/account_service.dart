import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class Profile {
  final String userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String address;
  final DateTime createdAt;

  Profile.fromJson(Map<String, dynamic> j)
      : userId = (j['userId'] ?? '') as String,
        fullName = (j['fullName'] ?? '') as String,
        email = (j['email'] ?? '') as String,
        phoneNumber = (j['phoneNumber'] ?? '') as String,
        address = (j['address'] ?? '') as String,
        createdAt = DateTime.parse(j['createdAt'] as String);
}

class AccountService {
  Future<Profile> getProfile() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Account/me'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Profile> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String address,
  }) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Account/me'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'address': address.isEmpty ? null : address,
      }),
    );
    checkResponse(res);
    final profile = Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    await AuthService().saveFullName(profile.fullName);
    return profile;
  }

  /// Đổi mật khẩu xong server cấp token mới (token cũ ở mọi máy hết hiệu lực).
  Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Account/password'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    checkResponse(res);
    await AuthService().saveSession(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
