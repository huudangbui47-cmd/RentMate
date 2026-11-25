import 'package:flutter/material.dart';

import '../services/notification_service.dart';

import 'account_screen.dart';
import 'guest_screen.dart';
import 'home_screen.dart';
import 'my_items_screen.dart';
import 'my_rentals_screen.dart';
import 'notifications_screen.dart';
import 'wallet_screen.dart';
import '../widgets/kit.dart';
import '../services/favorite_service.dart';
import '../l10n/l10n.dart';
import '../theme.dart';

/// Khung chính: thanh điều hướng nổi kính mờ của mẫu Rentcars với 4 nút tròn.
/// Mỗi lần chuyển tab, tab đó tải lại dữ liệu mới.
/// guest = true: khách chưa đăng nhập, chỉ dùng được Khám phá và Đăng nhập (mục cuối).
class MainShell extends StatefulWidget {
  final int initialIndex;
  final bool guest;
  const MainShell({super.key, this.initialIndex = 0, this.guest = false});

  // Thứ tự tab: 0 Khám phá · 1 Chuyến thuê · 2 Tin nhắn · 3 Tài khoản
  static const exploreTab = 0;
  static const rentalsTab = 1;
  static const chatTab = 2;
  static const accountTab = 3;
  // Không phải tab: thông báo về đồ / ví mở màn hình riêng (khớp AppNotification.targetTab)
  static const itemsTarget = 4;
  static const walletTarget = 5;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late int _index = widget.initialIndex;
  final _notifications = NotificationCenter.instance;

  @override
  void initState() {
    super.initState();
    // Tim đã lưu (khách chưa đăng nhập thì để trống)
    FavoriteCenter.load();
    if (widget.guest) return;
    // Đã đăng nhập: theo dõi thông báo mới, chạm thông báo thì chuyển đúng tab
    NotificationsScreen.register();
    _notifications.openTab = (tab) {
      if (!mounted) return;
      if (tab == MainShell.walletTarget) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen(standalone: true)));
      } else if (tab == MainShell.itemsTarget) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyItemsScreen()));
      } else {
        setState(() {
          _index = tab;
        });
      }
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

  void _select(int i) {
    if (widget.guest && i != MainShell.exploreTab && i != MainShell.accountTab) {
      requireLogin(context, tr('dùng tính năng này'));
      return;
    }
    setState(() {
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (widget.guest) {
      body = _index == MainShell.accountTab ? const GuestScreen() : const HomeScreen();
    } else {
      body = switch (_index) {
        MainShell.rentalsTab => const MyRentalsScreen(),
        MainShell.chatTab => ComingSoonScreen(
          title: tr('Tin nhắn'),
          icon: Icons.chat_bubble_outline_rounded,
          message: tr('Nhắn tin trực tiếp với chủ đồ sẽ có trong bản cập nhật tới.'),
        ),
        MainShell.accountTab => const AccountScreen(),
        _ => const HomeScreen(),
      };
    }
    const icons = [
      Icons.search_rounded,
      Icons.calendar_today_outlined,
      Icons.chat_bubble_outline_rounded,
      Icons.person_outline_rounded,
    ];
    return Scaffold(
      extendBody: true, // nội dung chạy dưới thanh điều hướng nổi như mẫu
      body: body,
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: navPillHidden,
        builder: (_, hidden, child) => IgnorePointer(
          ignoring: hidden,
          child: AnimatedSlide(
            offset: hidden ? const Offset(0, 1.5) : Offset.zero,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          ),
        ),
        child: widget.guest
            ? RcNavPill(index: _index, onTap: _select, icons: icons)
            : ValueListenableBuilder<int>(
                valueListenable: _notifications.unread,
                // Chấm đỏ trên nút Tài khoản khi có thông báo chưa đọc
                builder: (_, unread, _) => RcNavPill(
                  index: _index,
                  onTap: _select,
                  icons: icons,
                  dots: unread > 0 ? const {MainShell.accountTab} : const {},
                ),
              ),
      ),
    );
  }
}

/// true khi đang mở menu ☰ ở Trang chủ: ẩn thanh điều hướng nổi để không đè lên menu.
final navPillHidden = ValueNotifier<bool>(false);

/// Khoảng trống cuối danh sách để nội dung không bị thanh điều hướng nổi che.
double navPillSpace(BuildContext context) => 96 + MediaQuery.of(context).padding.bottom;

/// Tab chưa có tính năng (Tin nhắn): giữ chỗ cho tới khi làm xong.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          RcHeroBar(title: title),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 120),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 36, color: AppColors.ink),
                    ),
                    const SizedBox(height: 20),
                    Text(title, style: kTitle),
                    const SizedBox(height: 6),
                    Text(message, textAlign: TextAlign.center, style: kBody12Hint),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
