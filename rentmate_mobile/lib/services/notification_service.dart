import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type; // tên enum NotificationType trên server
  final bool isRead;
  final DateTime createdAt; // UTC

  AppNotification.fromJson(Map<String, dynamic> j)
      : id = j['notificationId'] as int,
        title = (j['title'] ?? '') as String,
        message = (j['message'] ?? '') as String,
        type = (j['type'] ?? '') as String,
        isRead = (j['isRead'] ?? false) as bool,
        // Server trả giờ UTC nhưng có thể thiếu chữ "Z"
        createdAt = _parseUtc(j['createdAt'] as String);

  static DateTime _parseUtc(String s) {
    final d = DateTime.parse(s);
    return d.isUtc ? d : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  }

  /// Tab trong MainShell cần mở khi chạm vào thông báo: 1 Đơn thuê, 2 Đồ của tôi, 3 Ví.
  int? get targetTab => switch (type) {
        'RentalRequest' || 'RentalApproved' || 'RentalRejected' || 'Payment' || 'ReturnReminder' || 'System' => 1,
        'Item' => 2,
        'Wallet' => 3,
        _ => null,
      };

  IconData get icon => switch (type) {
        'RentalRequest' => Icons.mark_email_unread_outlined,
        'RentalApproved' => Icons.check_circle_outline,
        'RentalRejected' => Icons.cancel_outlined,
        'Payment' => Icons.payments_outlined,
        'ReturnReminder' => Icons.assignment_return_outlined,
        'Item' => Icons.inventory_2_outlined,
        'Wallet' => Icons.account_balance_wallet_outlined,
        _ => Icons.notifications_outlined,
      };
}

class NotificationService {
  Future<List<AppNotification>> getMine() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/Notifications'), headers: await AuthService().authHeaders());
    checkResponse(res);
    return (jsonDecode(res.body) as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> getUnreadCount() async {
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/Notifications/unread-count'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
    return (jsonDecode(res.body) as Map<String, dynamic>)['count'] as int;
  }

  Future<void> markRead(int id) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Notifications/$id/read'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }

  Future<void> markAllRead() async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl/api/Notifications/read-all'),
      headers: await AuthService().authHeaders(),
    );
    checkResponse(res);
  }
}

/// Theo dõi số thông báo chưa đọc khi app đang mở: hỏi server mỗi 20 giây,
/// có thông báo mới thì cập nhật số trên chuông và hiện popup.
/// shortcut: hỏi định kỳ thay vì push thật (Firebase); app tắt hẳn thì không nhận được.
class NotificationCenter {
  NotificationCenter._();
  static final instance = NotificationCenter._();

  static const _interval = Duration(seconds: 20);

  final unread = ValueNotifier<int>(0);

  /// MainShell gán hàm này để chuyển tab khi chạm vào thông báo.
  void Function(int tab)? openTab;

  /// Mở màn hình danh sách thông báo (gán ở notifications_screen.dart để tránh import vòng).
  void Function()? openList;

  Timer? _timer;
  bool _checking = false;
  bool _hasBaseline = false; // lần hỏi đầu tiên chỉ lấy mốc, không hiện popup cho thông báo cũ

  void start() {
    _timer?.cancel();
    refresh();
    _timer = Timer.periodic(_interval, (_) => refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Đăng xuất: dừng và xóa số đếm.
  void reset() {
    stop();
    unread.value = 0;
    _hasBaseline = false;
  }

  Future<void> refresh({bool announce = true}) async {
    if (_checking) return;
    _checking = true;
    try {
      final service = NotificationService();
      final count = await service.getUnreadCount();
      final previous = unread.value;
      unread.value = count;
      final isNew = _hasBaseline && count > previous;
      _hasBaseline = true;
      if (announce && isNew) {
        final latest = (await service.getMine()).where((n) => !n.isRead).toList();
        _showPopup(count - previous == 1 && latest.isNotEmpty ? latest.first : null, count - previous);
      }
    } catch (_) {
      // Mất mạng hoặc server tắt: lần sau thử lại
    } finally {
      _checking = false;
    }
  }

  void _showPopup(AppNotification? single, int newCount) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(single?.icon ?? Icons.notifications_active_outlined, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(single?.title ?? 'Bạn có $newCount thông báo mới',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (single != null) Text(single.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(label: 'Xem', onPressed: () => openList?.call()),
      ));
  }
}
