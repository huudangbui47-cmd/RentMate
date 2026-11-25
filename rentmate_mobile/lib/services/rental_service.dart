import 'dart:convert';

import 'package:http/http.dart' as http;

import 'item_service.dart' show imageFullUrl;

import 'auth_service.dart';
import 'config_service.dart';
import '../l10n/l10n.dart';

class Rental {
  final int id;
  final int itemId;
  final String itemName;
  final String? itemImageUrl;
  final String categoryName;
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

  // Giao nhận
  final String deliveryMethod; // "Meetup" | "Ghn"
  final String? shippingOrderCode;
  final DateTime? expectedDeliveryAt;
  final int shiftedDays;
  final num lateDeliveryRefund;
  final int discountPercent; // ưu đãi thuê dài ngày đã trừ vào totalPrice
  final num discountAmount;
  final num platformFeePercent;

  /// Phí nền tảng của đơn này, vd. "5" hoặc "2,5"
  String get feeText => platformFeePercent == platformFeePercent.roundToDouble()
      ? platformFeePercent.toStringAsFixed(0)
      : platformFeePercent.toString().replaceAll('.', ',');
  final String? cancelReason;

  Rental.fromJson(Map<String, dynamic> j)
    : id = j['rentalId'] as int,
      itemId = j['itemId'] as int,
      itemName = (j['itemName'] ?? '') as String,
      itemImageUrl = j['itemImageUrl'] == null ? null : imageFullUrl(j['itemImageUrl'] as String),
      categoryName = (j['categoryName'] ?? '') as String,
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
      renterResponseDeadline = _parse(j['renterResponseDeadline']),
      deliveryMethod = (j['deliveryMethod'] ?? 'Meetup') as String,
      shippingOrderCode = j['shippingOrderCode'] as String?,
      expectedDeliveryAt = _parse(j['expectedDeliveryAt']),
      shiftedDays = (j['shiftedDays'] ?? 0) as int,
      lateDeliveryRefund = (j['lateDeliveryRefund'] ?? 0) as num,
      discountPercent = (j['discountPercent'] ?? 0) as int,
      discountAmount = (j['discountAmount'] ?? 0) as num,
      platformFeePercent = (j['platformFeePercent'] ?? 5) as num,
      cancelReason = j['cancelReason'] as String?;

  bool get isShipping => deliveryMethod == 'Ghn';

  static DateTime? _parse(dynamic v) => v == null ? null : _asUtc(DateTime.parse(v as String));

  static bool _passed(DateTime? deadline) => deadline != null && DateTime.now().toUtc().isAfter(_asUtc(deadline));

  /// Chủ đồ quá hạn kiểm tra (cài đặt hệ thống) chưa kiểm tra đồ: người thuê được tự hoàn tất, nhận đủ cọc.
  bool get renterCanForceComplete => status == 'Returned' && _passed(ownerInspectionDeadline);

  /// Người thuê quá hạn phản hồi bồi thường: chủ đồ được chốt mức đã đề nghị.
  bool get ownerCanFinalizeDamage => status == 'DamageClaimed' && _passed(renterResponseDeadline);

  /// Tiền người thuê phải trả khi thanh toán (thuê + cọc).
  num get amountToPay => totalPrice + depositAmount;

  int get days => endDate.difference(startDate).inDays + 1;

  /// Chủ đồ được hủy đơn đã duyệt nếu người thuê chưa thanh toán sau hạn trong cài đặt hệ thống.
  bool get ownerCanCancel =>
      status == 'Approved' &&
      approvedAt != null &&
      DateTime.now().toUtc().difference(_asUtc(approvedAt!)) >= Duration(hours: AppConfig.paymentTimeoutHours);

  // Server trả giờ UTC nhưng có thể thiếu chữ "Z".
  static DateTime _asUtc(DateTime d) => d.isUtc ? d : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
}

// Theo RentalStatus trong RentMate.Core.
Map<String, String> get rentalStatusLabels => {
  'Pending': tr('Chờ duyệt'),
  'Approved': tr('Chờ thanh toán'),
  'WaitingForPickup': tr('Chờ nhận đồ'),
  'Rejected': tr('Bị từ chối'),
  'Cancelled': tr('Đã hủy'),
  'Rented': tr('Đang thuê'),
  'Returned': tr('Đã trả đồ'),
  'Completed': tr('Hoàn tất'),
  'Overdue': tr('Quá hạn'),
  'DamageClaimed': tr('Chờ xác nhận bồi thường'),
  'Disputed': tr('Đang khiếu nại'),
};

class RentalService {
  Future<List<Rental>> getMyRentals() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Rentals/my'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List).map((e) => Rental.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createRental({
    required int itemId,
    required DateTime startDate,
    required DateTime endDate,
    String? note,
    ShipTo? shipTo,
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Rentals'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({
        'itemId': itemId,
        'startDate': _dateOnly(startDate),
        'endDate': _dateOnly(endDate),
        'requestNote': (note == null || note.isEmpty) ? null : note,
        // 1 = gặp trực tiếp, 2 = giao qua GHN
        'deliveryMethod': shipTo == null ? 1 : 2,
        if (shipTo != null) ...shipTo.toJson(),
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

  /// Hủy đơn, có thể kèm lý do (vd. từ chối nhận vì đồ khác tin đăng).
  Future<void> cancel(int rentalId, {String? reason}) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/cancel'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'reason': reason}),
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
  String _dateOnly(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Địa chỉ nhận hàng khi chọn giao qua GHN.
class ShipTo {
  final String name;
  final String phone;
  final String address;
  final int districtId;
  final String wardCode;
  final String areaText;
  const ShipTo({
    required this.name,
    required this.phone,
    required this.address,
    required this.districtId,
    required this.wardCode,
    required this.areaText,
  });

  Map<String, dynamic> toJson() => {
    'shipToName': name,
    'shipToPhone': phone,
    'shipToAddress': address,
    'shipToDistrictId': districtId,
    'shipToWardCode': wardCode,
    'shipToAreaText': areaText,
  };
}
