import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../widgets/ui.dart';

/// Chuông thông báo có số chưa đọc, đặt ở AppBar các tab chính.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationCenter.instance.unread,
      builder: (context, count, _) => IconButton(
        tooltip: 'Thông báo',
        onPressed: () => NotificationsScreen.open(),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
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
    setState(() { _future = _load(); });
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
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(onPressed: _markAll, child: const Text('Đọc hết')),
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
                ? ListView(children: const [
                    EmptyView(
                      icon: Icons.notifications_none_rounded,
                      title: 'Chưa có thông báo',
                      subtitle: 'Khi đơn thuê, ví hoặc đồ của bạn có thay đổi, thông báo sẽ hiện ở đây.',
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _tile(list[i]),
                  ),
          );
        },
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: n.isRead ? Colors.transparent : scheme.primary.withValues(alpha: 0.06),
      child: ListTile(
        onTap: () => _open(n),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(n.icon, color: scheme.primary),
        ),
        title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(n.message),
            const SizedBox(height: 4),
            Text(_timeAgo(n.createdAt), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ),
        trailing: n.isRead ? null : CircleAvatar(radius: 5, backgroundColor: scheme.primary),
        isThreeLine: true,
      ),
    );
  }

  static String _timeAgo(DateTime utc) {
    final diff = DateTime.now().toUtc().difference(utc);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return fmtDateTime(utc);
  }
}
