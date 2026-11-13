import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';

/// Về màn hình đăng nhập (xóa chế độ khách); register = true thì mở luôn trang đăng ký.
void _goToLogin(BuildContext context, {bool register = false}) {
  final navigator = Navigator.of(context);
  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  if (register) navigator.push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
}

/// Khách bấm vào chức năng cần tài khoản: mời đăng nhập hoặc đăng ký.
Future<void> requireLogin(BuildContext context, String action) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cần đăng nhập'),
      content: Text('Bạn cần đăng nhập để $action.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Để sau')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            _goToLogin(context, register: true);
          },
          child: const Text('Đăng ký'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            _goToLogin(context);
          },
          child: const Text('Đăng nhập'),
        ),
      ],
    ),
  );
}

/// Tab "Đăng nhập" của khách.
class GuestScreen extends StatelessWidget {
  const GuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.person_outline, size: 64, color: scheme.primary),
              const SizedBox(height: 12),
              const Text('Bạn đang xem với tư cách khách',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Đăng nhập để thuê đồ, đăng đồ cho thuê, xem hồ sơ người khác và quản lý ví.',
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => _goToLogin(context), child: const Text('Đăng nhập')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _goToLogin(context, register: true),
                child: const Text('Đăng ký tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
