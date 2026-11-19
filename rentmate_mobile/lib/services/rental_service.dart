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
  final num pricePerDay;
  final num totalPrice;
  final num depositAmount;
  final String status;
  final String? requestNote;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? receivedAt;
  final DateTime? returnedAt;

  // Bồi thường / khiếu nại
  final num damageAmount;
  final String? damageNote;
  final String? disputeReason;
  final String? resolutionNote;
  final DateTime? ownerInspectionDeadline;
  final DateTime? renterResponseDeadline;

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
        pricePerDay = (j['pricePerDay'] ?? 0) as num,
        totalPrice = (j['totalPrice'] ?? 0) as num,
        depositAmount = (j['depositAmount'] ?? 0) as num,
        status = (j['status'] ?? '') as String,
        requestNote = j['requestNote'] as String?,
        requestedAt = DateTime.parse(j['requestedAt'] as String),
        approvedAt = j['approvedAt'] == null ? null : DateTime.parse(j['approvedAt'] as String),
        receivedAt = _parse(j['receivedAt']),
        returnedAt = _parse(j['returnedAt']),
        damageAmount = (j['damageAmount'] ?? 0) as num,
        damageNote = j['damageNote'] as String?,
        disputeReason = j['disputeReason'] as String?,
        resolutionNote = j['resolutionNote'] as String?,
        ownerInspectionDeadline = _parse(j['ownerInspectionDeadline']),
        renterResponseDeadline = _parse(j['renterResponseDeadline']);

  static DateTime? _parse(dynamic v) => v == null ? null : _asUtc(DateTime.parse(v as String));

  static bool _passed(DateTime? deadline) => deadline != null && DateTime.now().toUtc().isAfter(_asUtc(deadline));

  /// Chủ đồ quá 3 ngày chưa kiểm tra đồ: người thuê được tự hoàn tất, nhận đủ cọc.
  bool get renterCanForceComplete => status == 'Returned' && _passed(ownerInspectionDeadline);

  /// Người thuê quá 2 ngày không phản hồi bồi thường: chủ đồ được chốt mức đã đề nghị.
  bool get ownerCanFinalizeDamage => status == 'DamageClaimed' && _passed(renterResponseDeadline);

  /// Tiền người thuê phải trả khi thanh toán (thuê + cọc).
  num get amountToPay => totalPrice + depositAmount;

  int get days => endDate.difference(startDate).inDays + 1;

  /// Chủ đồ được hủy đơn đã duyệt nếu người thuê chưa thanh toán sau 24 giờ (theo RentalService.cs).
  bool get ownerCanCancel =>
      status == 'Approved' &&
      approvedAt != null &&
      DateTime.now().toUtc().difference(_asUtc(approvedAt!)) >= const Duration(hours: 24);

  // Server trả giờ UTC nhưng có thể thiếu chữ "Z".
  static DateTime _asUtc(DateTime d) =>
      d.isUtc ? d : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
}

// Theo RentalStatus trong RentMate.Core.
const rentalStatusLabels = {
  'Pending': 'Chờ duyệt',
  'Approved': 'Chờ thanh toán',
  'WaitingForPickup': 'Chờ nhận đồ',
  'Rejected': 'Bị từ chối',
  'Cancelled': 'Đã hủy',
  'Rented': 'Đang thuê',
  'Returned': 'Đã trả đồ',
  'Completed': 'Hoàn tất',
  'Overdue': 'Quá hạn',
  'DamageClaimed': 'Chờ xác nhận bồi thường',
  'Disputed': 'Đang khiếu nại',
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
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
        'requestNote': (note == null || note.isEmpty) ? null : note,
      }),
    );
    checkResponse(res);
  }

  /// action: approve | reject | pay | cancel | pickup | return | complete | accept-damage
  Future<void> updateStatus(int rentalId, String action) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/$action'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }

  /// Hoàn tất đơn. Chủ đồ gửi số tiền trừ cọc (0 = hoàn đủ); người thuê gọi không kèm gì khi chủ đồ quá hạn kiểm tra.
  Future<void> complete(int rentalId, {num damageAmount = 0, String? damageNote}) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/complete'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'damageAmount': damageAmount, 'damageNote': damageNote}),
    );
    checkResponse(res);
  }

  Future<void> dispute(int rentalId, String reason) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/dispute'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'reason': reason}),
    );
    checkResponse(res);
  }

  // Gửi đúng ngày đã chọn, không kèm giờ/múi giờ để server không lệch sang ngày khác.
  String _dateOnly(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
