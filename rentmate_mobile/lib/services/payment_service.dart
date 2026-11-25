import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class VnPayPayment {
  final String paymentUrl;
  final String code;
  final num amount;
  VnPayPayment.fromJson(Map<String, dynamic> j)
    : paymentUrl = j['paymentUrl'] as String,
      code = (j['code'] ?? '') as String,
      amount = (j['amount'] ?? 0) as num;
}

/// Nạp ví qua cổng VNPay (sandbox).
class PaymentService {
  /// Đường dẫn VNPay chuyển về sau khi thanh toán; thấy đường dẫn này là xong.
  static const returnPath = '/api/payments/vnpay-return';

  Future<bool> isVnPayEnabled() async {
    try {
      final res = await http.get(
        Uri.parse('$apiBaseUrl/api/payments/vnpay/enabled'),
        headers: await AuthService().authHeaders(),
      );
      checkResponse(res);
      return (jsonDecode(res.body) as Map<String, dynamic>)['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// amount: nạp vào ví; rentalId: nạp đúng số còn thiếu để trả đơn (server tự tính, xong tự trả đơn).
  Future<VnPayPayment> createVnPay({num? amount, int? rentalId}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/payments/vnpay'),
      headers: await AuthService().authHeaders(),
      body: jsonEncode({'amount': amount, 'rentalId': rentalId}),
    );
    checkResponse(res);
    return VnPayPayment.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
