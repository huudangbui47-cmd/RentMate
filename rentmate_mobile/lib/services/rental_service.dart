import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class Rental {
  final int id;
  final int itemId;
  final String itemName;
  final String renterId;
  final String renterName;
  final String ownerId;
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
        renterId = (j['renterId'] ?? '') as String,
        renterName = (j['renterName'] ?? '') as String,
        ownerId = (j['ownerId'] ?? '') as String,
        ownerName = (j['ownerName'] ?? '') as String,
        startDate = DateTime.parse(j['startDate'] as String),
        endDate = DateTime.parse(j['endDate'] as String),
        totalPrice = (j['totalPrice'] ?? 0) as num,
        depositAmount = (j['depositAmount'] ?? 0) as num,
        status = (j['status'] ?? '') as String,
        requestNote = j['requestNote'] as String?;
}

// Theo RentalStatus trong RentalService.cs.
const rentalStatusLabels = {
  'Pending': 'Chờ duyệt',
  'Approved': 'Đã duyệt',
  'WaitingForPickup': 'Chờ giao đồ',
  'Rejected': 'Bị từ chối',
  'Rented': 'Đang thuê',
  'Returned': 'Đã trả đồ',
  'Completed': 'Hoàn tất',
};

class RentalService {
  Future<List<Rental>> getMyRentals() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Rentals/my'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
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
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Rentals'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({
        'itemId': itemId,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'requestNote': (note == null || note.isEmpty) ? null : note,
      }),
    );
    checkResponse(res);
  }

  /// action: approve | reject | pickup | return | complete
  Future<void> updateStatus(int rentalId, String action) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/$action'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }
}