import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'item_service.dart';

/// Ảnh banner đầu Trang chủ do quản trị viên tải lên trên AdminSite.
class BannerService {
  /// Đường dẫn đầy đủ của các banner đang hiện, đúng thứ tự quản trị sắp xếp.
  /// Lỗi mạng thì trả danh sách rỗng (app dùng nền tối mặc định), không làm hỏng Trang chủ.
  Future<List<String>> getBannerUrls() async {
    try {
      final res = await http.get(Uri.parse('$apiBaseUrl/api/Banners'));
      if (res.statusCode != 200) return [];
      return (jsonDecode(res.body) as List)
          .map((e) => imageFullUrl((e as Map<String, dynamic>)['imageUrl'] as String))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

/// Banner dùng chung cho đầu trang của mọi màn (tải một lần khi mở app, tải lại khi kéo làm mới Trang chủ).
class BannerCenter {
  static final banners = ValueNotifier<List<String>>(const []);

  static Future<void> load() async {
    final urls = await BannerService().getBannerUrls();
    if (urls.isNotEmpty || banners.value.isNotEmpty) banners.value = urls;
  }
}
