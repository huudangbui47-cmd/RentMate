import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'auth_service.dart';
import 'item_service.dart' show imageFullUrl;

class Profile {
  final String userId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String address;
  final String? avatarUrl; // null nếu chưa có ảnh đại diện
  final DateTime createdAt;

  Profile.fromJson(Map<String, dynamic> j)
      : userId = (j['userId'] ?? '') as String,
        fullName = (j['fullName'] ?? '') as String,
        email = (j['email'] ?? '') as String,
        phoneNumber = (j['phoneNumber'] ?? '') as String,
        address = (j['address'] ?? '') as String,
        avatarUrl = j['avatarUrl'] == null ? null : imageFullUrl(j['avatarUrl'] as String),
        createdAt = DateTime.parse(j['createdAt'] as String);
}

/// Hồ sơ công khai của người khác (không có email, số điện thoại, địa chỉ).
class PublicProfile {
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final DateTime createdAt;

  PublicProfile.fromJson(Map<String, dynamic> j)
      : userId = (j['userId'] ?? '') as String,
        fullName = (j['fullName'] ?? '') as String,
        avatarUrl = j['avatarUrl'] == null ? null : imageFullUrl(j['avatarUrl'] as String),
        createdAt = DateTime.parse(j['createdAt'] as String);
}

class AccountService {
  Future<PublicProfile> getPublicProfile(String userId) async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Users/$userId'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
    return PublicProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

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

  Future<Profile> uploadAvatar(XFile file) async {
    final headers = await AuthService().authHeaders();
    headers.remove('Content-Type'); // MultipartRequest tự đặt Content-Type
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/Account/avatar'))
      ..headers.addAll(headers)
      ..files.add(await http.MultipartFile.fromPath('file', file.path, filename: file.name));
    final res = await http.Response.fromStream(await req.send());
    checkResponse(res);
    return Profile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
