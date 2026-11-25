import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'item_service.dart';

/// Danh sách yêu thích (tim trên app), lưu trên server theo tài khoản.
class FavoriteService {
  Future<List<Item>> getFavorites() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Favorites'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Set<int>> getIds() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Favorites/ids'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List).map((e) => e as int).toSet();
  }

  Future<void> add(int itemId) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/Favorites/$itemId'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }

  Future<void> remove(int itemId) async {
    final res = await http.delete(
      Uri.parse('$apiBaseUrl/api/Favorites/$itemId'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }
}

/// Id các món đã lưu, dùng chung cho mọi trái tim trong app (Trang chủ, chi tiết đồ, màn Yêu thích).
class FavoriteCenter {
  static final ids = ValueNotifier<Set<int>>(const {});

  /// Tải khi mở app / đăng nhập. Khách chưa đăng nhập hoặc lỗi mạng thì để trống.
  static Future<void> load() async {
    if (await AuthService().getToken() == null) {
      ids.value = const {};
      return;
    }
    try {
      ids.value = await FavoriteService().getIds();
    } catch (_) {}
  }

  static void clear() => ids.value = const {};

  /// Đổi tim ngay cho mượt, gọi Api sau; lỗi thì trả lại như cũ và ném lỗi để màn hình báo.
  static Future<void> toggle(int itemId) async {
    final before = ids.value;
    final saved = before.contains(itemId);
    ids.value = saved ? ({...before}..remove(itemId)) : {...before, itemId};
    try {
      if (saved) {
        await FavoriteService().remove(itemId);
      } else {
        await FavoriteService().add(itemId);
      }
    } catch (_) {
      ids.value = before;
      rethrow;
    }
  }
}
