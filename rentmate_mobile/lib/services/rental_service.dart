import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class RentalService {
  Future<void> createRental({
    required int itemId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
  }) async {
    final token = await AuthService().getToken();
    if (token == null) throw Exception('Bạn cần đăng nhập lại');

    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Rentals'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'itemId': itemId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'requestNote': (note == null || note.isEmpty) ? null : note,
      }),
    );
    if (res.statusCode == 401)
      throw Exception('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(apiErrorMessage(res));
    }
  }
}
