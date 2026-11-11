import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

// shortcut: trang chủ tạm để kiểm tra đăng nhập, thay bằng danh sách đồ ở bước sau.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RentMate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: FutureBuilder<String?>(
          future: AuthService().getFullName(),
          builder: (context, snap) =>
              Text('Xin chào ${snap.data ?? ''}!',
                  style: Theme.of(context).textTheme.titleLarge),
        ),
      ),
    );
  }
}
