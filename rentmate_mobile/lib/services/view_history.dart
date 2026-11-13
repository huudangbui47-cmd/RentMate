import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Một lượt xem chi tiết món đồ.
class ItemViewRecord {
  final int itemId;
  final int categoryId;
  final DateTime viewedAt;
  ItemViewRecord(this.itemId, this.categoryId, this.viewedAt);
}

/// Lịch sử xem món đồ, lưu trên điện thoại theo từng tài khoản, dùng để gợi ý ở trang chủ.
/// shortcut: mất khi xoá app / đổi máy; muốn giữ lâu dài thì chuyển lên server (bảng ItemViews).
class ViewHistory {
  static const _maxRecords = 100;

  static String _key(String userId) => 'viewHistory_$userId';

  /// Mỗi món chỉ giữ lần xem gần nhất, mới nhất đứng đầu.
  static Future<void> record(String userId, int itemId, int categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _decode(prefs.getString(_key(userId)))..removeWhere((r) => r.itemId == itemId);
    list.insert(0, ItemViewRecord(itemId, categoryId, DateTime.now()));
    if (list.length > _maxRecords) list.removeRange(_maxRecords, list.length);
    await prefs.setString(
      _key(userId),
      jsonEncode([
        for (final r in list) {'i': r.itemId, 'c': r.categoryId, 't': r.viewedAt.millisecondsSinceEpoch}
      ]),
    );
  }

  static Future<List<ItemViewRecord>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_key(userId)));
  }

  static List<ItemViewRecord> _decode(String? raw) {
    if (raw == null) return [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          ItemViewRecord(e['i'] as int, e['c'] as int, DateTime.fromMillisecondsSinceEpoch(e['t'] as int))
      ];
    } catch (_) {
      return []; // dữ liệu hỏng thì bỏ qua, ghi lại từ đầu
    }
  }
}
