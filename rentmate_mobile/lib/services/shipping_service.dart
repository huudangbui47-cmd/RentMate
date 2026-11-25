import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Một dòng tỉnh / quận / phường lấy từ GHN.
class AddressOption {
  final String id;
  final String name;
  AddressOption.fromJson(Map<String, dynamic> j)
      : id = '${j['id']}',
        name = (j['name'] ?? '') as String;
}

/// Một mốc trên dòng thời gian giao nhận.
class ShippingStep {
  final String title;
  final String? detail;
  final DateTime? time;
  final bool done;
  ShippingStep.fromJson(Map<String, dynamic> j)
      : title = (j['title'] ?? '') as String,
        detail = j['detail'] as String?,
        time = j['time'] == null ? null : DateTime.parse(j['time'] as String),
        done = (j['done'] ?? false) as bool;
}

class ShippingTracking {
  final String deliveryMethod; // "Meetup" | "Ghn"
  final String? orderCode;
  final String? statusText;
  final num? shippingFee;
  final DateTime? expectedDeliveryAt;
  final String? shipToText;
  final String? warning;
  final List<ShippingStep> steps;

  ShippingTracking.fromJson(Map<String, dynamic> j)
      : deliveryMethod = (j['deliveryMethod'] ?? 'Meetup') as String,
        orderCode = j['orderCode'] as String?,
        statusText = j['statusText'] as String?,
        shippingFee = j['shippingFee'] as num?,
        expectedDeliveryAt = j['expectedDeliveryAt'] == null ? null : DateTime.parse(j['expectedDeliveryAt'] as String),
        shipToText = j['shipToText'] as String?,
        warning = j['warning'] as String?,
        steps = ((j['steps'] ?? []) as List).map((e) => ShippingStep.fromJson(e as Map<String, dynamic>)).toList();
}

/// Giao hàng qua GHN (Api gọi GHN hộ app).
class ShippingService {
  Future<bool> isEnabled() async {
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/shipping/enabled'), headers: await AuthService().authHeaders());
      checkResponse(res);
      return (jsonDecode(res.body) as Map<String, dynamic>)['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<AddressOption>> provinces() => _list('provinces');
  Future<List<AddressOption>> districts(String provinceId) => _list('districts?provinceId=$provinceId');
  Future<List<AddressOption>> wards(String districtId) => _list('wards?districtId=$districtId');

  Future<List<AddressOption>> _list(String path) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/shipping/$path'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List).map((e) => AddressOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ShippingTracking> tracking(int rentalId) async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/shipping'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return ShippingTracking.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Chủ đồ gửi hàng: Api tạo vận đơn GHN.
  Future<void> createShipment(int rentalId, int weightGram) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Rentals/$rentalId/shipment'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'weightGram': weightGram}),
    );
    checkResponse(res);
  }
}
