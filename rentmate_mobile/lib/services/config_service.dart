import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

/// Cài đặt hệ thống do quản trị viên chỉnh ở trang "Cài đặt hệ thống" (GET api/settings).
/// Tải khi mở app; mất mạng thì dùng bản đã lưu lần trước, chưa có thì dùng giá trị mặc định.
class AppConfig {
  AppConfig._();

  static double platformFeePercent = 5;
  static int minWalletAmount = 10000;
  static int maxWalletAmount = 50000000;
  static int maxRentalDays = 30;
  static int maxDaysAhead = 90;
  static int paymentTimeoutHours = 24;
  static int ownerInspectionDays = 3;
  static int renterResponseDays = 2;
  static int maxItemImages = 8;
  static int maxReportImages = 6;
  static String? supportPhone;
  static String? supportEmail;

  static const _prefKey = 'app_config';

  /// 5 → "5", 2.5 → "2,5"
  static String get feeText {
    final v = platformFeePercent;
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');
  }

  static Future<void> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefKey);
      if (cached != null) _apply(jsonDecode(cached) as Map<String, dynamic>);
    } catch (_) {
      // Bản lưu hỏng thì bỏ qua
    }
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/settings')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final body = utf8.decode(res.bodyBytes);
        _apply(jsonDecode(body) as Map<String, dynamic>);
        await prefs?.setString(_prefKey, body);
      }
    } catch (_) {
      // Không có mạng / Api chưa chạy: dùng bản đã lưu hoặc mặc định
    }
  }

  static void _apply(Map<String, dynamic> j) {
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    platformFeePercent = (j['platformFeePercent'] as num?)?.toDouble() ?? platformFeePercent;
    minWalletAmount = i('minWalletAmount', minWalletAmount);
    maxWalletAmount = i('maxWalletAmount', maxWalletAmount);
    maxRentalDays = i('maxRentalDays', maxRentalDays);
    maxDaysAhead = i('maxDaysAhead', maxDaysAhead);
    paymentTimeoutHours = i('paymentTimeoutHours', paymentTimeoutHours);
    ownerInspectionDays = i('ownerInspectionDays', ownerInspectionDays);
    renterResponseDays = i('renterResponseDays', renterResponseDays);
    maxItemImages = i('maxItemImages', maxItemImages);
    maxReportImages = i('maxReportImages', maxReportImages);
    supportPhone = (j['supportPhone'] as String?)?.trim();
    supportEmail = (j['supportEmail'] as String?)?.trim();
    if (supportPhone?.isEmpty ?? false) supportPhone = null;
    if (supportEmail?.isEmpty ?? false) supportEmail = null;
  }
}
