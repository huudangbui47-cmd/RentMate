import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class Rental {
  final int id;
  final int itemId;
  final String itemName;
  final String ownerName;
  final DateTime startDate;
  final DateTime endDate;
  final num totalPrice;
  final num depositAmount;
  final String status;
  final String? requestNote;

  Rental.fromJson(Map<String, dynamic> j)
      : id = j['rentalId'] as int,
        itemId = j['itemId'] as int,
        itemName = (j['itemName'] ?? '') as String,
        ownerName = (j['ownerName'] ?? '') as String,
        startDate = DateTime.parse(j['startDate'] as String),
        endDate = DateTime.parse(j['endDate'] as String),
        totalPrice = (j['totalPrice'] ?? 0) as num,
        depositAmount = (j['depositAmount'] ?? 0) as num,
        status = (j['status'] ?? '') as String,
        requestNote = j['requestNote'] as String?;
}

// shortcut: chỉ chắc chắn có "Pending"; các tên khác đoán theo các API approve/reject/pickup/return/complete, trạng thái lạ sẽ hiện nguyên tên tiếng Anh.
const rentalStatusLabels = {
  'Pending': 'Chờ duyệt',
  'Approved': 'Đã duyệt',
  'Rejected': 'Bị từ chối',
  'PickedUp': 'Đang thuê',
  'Returned': 'Đã trả đồ',
  'Completed': 'Hoàn tất',
  'Cancelled': 'Đã hủy',
};

class RentalService {
  Future<List<Rental>> getMyRentals() async {
    final token = await AuthService().getToken();
    if (token == null) throw Exception('Bạn cần đăng nhập lại');
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Rentals/my'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 401) throw Exception('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
    if (res.statusCode != 200) throw Exception(apiErrorMessage(res));
    return (jsonDecode(res.body) as List)
        .map((e) => Rental.fromJson(e as Map<String, dynamic>))
        .toList();
  }

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
    if (res.statusCode == 401) throw Exception('Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại');
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(apiErrorMessage(res));
    }
  }
}
