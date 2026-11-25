import 'package:flutter/material.dart';

import '../services/notification_service.dart';

import 'account_screen.dart';
import 'guest_screen.dart';
import 'home_screen.dart';
import 'my_items_screen.dart';
import 'my_rentals_screen.dart';
import 'notifications_screen.dart';
import 'wallet_screen.dart';
import '../l10n/l10n.dart';

/// Khung chính sau khi đăng nhập: thanh điều hướng dưới với 5 mục.
/// Mỗi lần chuyển tab, tab đó tải lại dữ liệu mới.
/// guest = true: khách chưa đăng nhập, chỉ có Khám phá và Đăng nhập.
class MainShell extends StatefulWidget {
  final int initialIndex;
  final bool guest;
  const MainShell({super.key, this.initialIndex = 0, this.guest = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;
  final _notifications = NotificationCenter.instance;

  @override
  void initState() {
    super.initState();
    if (widget.guest) return;
    // Đã đăng nhập: theo dõi thông báo mới, chạm thông báo thì chuyển đúng tab
    NotificationsScreen.register();
    _notifications.openTab = (tab) {
      if (mounted) setState(() { _index = tab; });
    };
    _notifications.start();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Chỉ hỏi server khi app đang mở trên màn hình; mở lại app thì kiểm tra ngay
    if (state == AppLifecycleState.resumed) {
      _notifications.start();
    } else if (state == AppLifecycleState.paused) {
      _notifications.stop();
    }
  }

  @override
  void dispose() {
    if (!widget.guest) {
      // MainShell chỉ bị bỏ khi đăng xuất hoặc hết phiên
      WidgetsBinding.instance.removeObserver(this);
      _notifications.openTab = null;
      _notifications.reset();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.guest) {
      return Scaffold(
        body: [const HomeScreen(), const GuestScreen()][_index],
        bottomNavigationBar: _floating(NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.storefront_outlined), selectedIcon: const Icon(Icons.storefront), label: tr('Khám phá')),
            NavigationDestination(icon: const Icon(Icons.login_rounded), label: tr('Đăng nhập')),
          ],
        )),
      );
    }
    final tabs = [
      const HomeScreen(),
      const MyRentalsScreen(),
      const MyItemsScreen(),
      const WalletScreen(),
      const AccountScreen(),
    ];
    return Scaffold(
      body: tabs[_index],
      bottomNavigationBar: _floating(NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: tr('Khám phá')),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: tr('Đơn thuê')),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: tr('Đồ của tôi')),
          NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: tr('Ví')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: tr('Tài khoản')),
        ],
      )),
    );
  }

  // Thanh điều hướng nổi: cách mép, bo tròn
  Widget _floating(Widget bar) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: ClipRRect(borderRadius: BorderRadius.circular(30), child: bar),
        ),
      );
}
