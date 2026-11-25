import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';
import '../l10n/l10n.dart';

/// Chuông thông báo có số chưa đọc, đặt ở AppBar các tab chính.
/// bordered = true: nút tròn có viền như đầu trang chủ của mẫu.
class NotificationBell extends StatelessWidget {
  final bool bordered;
  const NotificationBell({super.key, this.bordered = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationCenter.instance.unread,
      builder: (context, count, _) {
        final icon = Badge(
          isLabelVisible: count > 0,
          backgroundColor: AppColors.error,
          label: Text(count > 99 ? '99+' : '$count'),
          child: const Icon(Icons.notifications_none_rounded),
        );
        if (bordered) {
          return CircleIconButton(tooltip: tr('Thông báo'), onPressed: NotificationsScreen.open, icon: icon);
        }
        return IconButton(tooltip: tr('Thông báo'), onPressed: NotificationsScreen.open, icon: icon);
      },
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  /// Mở từ chuông hoặc từ nút "Xem" trên popup.
  static void open() {
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  /// Gọi một lần khi khởi động MainShell để popup biết cách mở màn hình này.
  static void register() => NotificationCenter.instance.openList = open;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _future = _load();

  Future<List<AppNotification>> _load() async {
    final list = await NotificationService().getMine();
    // Đồng bộ số trên chuông, không hiện popup
    NotificationCenter.instance.refresh(announce: false);
    return list;
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      try {
        await NotificationService().markRead(n.id);
      } catch (_) {
        // Không đánh dấu được thì vẫn mở màn hình liên quan
      }
      NotificationCenter.instance.refresh(announce: false);
    }
    final tab = n.targetTab;
    if (!mounted) return;
    if (tab == null) {
      await _reload();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    NotificationCenter.instance.openTab?.call(tab);
  }

  Future<void> _markAll() async {
    try {
      await NotificationService().markAllRead();
      await _reload();
    } catch (e) {
      if (mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RcAppBar(
        title: Text(tr('Thông báo')),
        actions: [
          IconButton(onPressed: _markAll, tooltip: tr('Đọc hết'), icon: const Icon(Icons.done_all_rounded, size: 24)),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done && !snap.hasData) return const LoadingView();
          if (snap.hasError) return ErrorView(message: errorText(snap.error!), onRetry: _reload);
          final list = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: list.isEmpty
                ? ListView(
                    children: [
                      EmptyView(
                        icon: Icons.notifications_none_rounded,
                        title: tr('Chưa có thông báo'),
                        subtitle: tr('Khi đơn thuê, ví hoặc đồ của bạn có thay đổi, thông báo sẽ hiện ở đây.'),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      // Mỗi nhóm ngày là một khối trắng có nhãn xám như "Preferences" / "Account" của mẫu
                      for (final group in _groups(list)) ...[
                        RcCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(group.key, style: kText(13, FontWeight.w300, color: AppColors.muted)),
                              for (var i = 0; i < group.value.length; i++)
                                _tile(group.value[i], last: i == group.value.length - 1),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
          );
        },
      ),
    );
  }

  /// Nhóm theo ngày như mẫu: Hôm nay / Hôm qua / Trước đó.
  List<MapEntry<String, List<AppNotification>>> _groups(List<AppNotification> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<AppNotification>>{};
    for (final n in list) {
      final l = n.createdAt.toLocal();
      final day = DateTime(l.year, l.month, l.day);
      final key = day == today
          ? tr('Hôm nay')
          : day == today.subtract(const Duration(days: 1))
          ? tr('Hôm qua')
          : tr('Trước đó');
      groups.putIfAbsent(key, () => []).add(n);
    }
    return groups.entries.toList();
  }

  Widget _tile(AppNotification n, {bool last = false}) {
    return InkWell(
      onTap: () => _open(n),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Badge(
              isLabelVisible: !n.isRead,
              smallSize: 9,
              backgroundColor: AppColors.error,
              alignment: const AlignmentDirectional(0.45, -0.55),
              child: RcIconCircle(n.icon, size: 40),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: last
                  ? null
                  : const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.divider)),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${n.title} ',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: n.message,
                          style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w300),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.45),
                  ),
                  const SizedBox(height: 4),
                  Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) return tr('Vừa xong');
    if (diff.inHours < 1) return tr('{0} phút trước', [diff.inMinutes]);
    if (diff.inDays < 1) return tr('{0} giờ trước', [diff.inHours]);
    if (diff.inDays < 7) return tr('{0} ngày trước', [diff.inDays]);
    return fmtDateTime(utc);
  }
}
