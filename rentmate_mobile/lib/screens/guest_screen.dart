import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import '../l10n/l10n.dart';
import '../widgets/language_picker.dart';
import 'main_shell.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import '../widgets/kit.dart';

/// Về màn hình đăng nhập (xóa chế độ khách); register = true thì mở luôn trang đăng ký.
void goToLogin(BuildContext context, {bool register = false}) {
  final navigator = Navigator.of(context);
  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  if (register) navigator.push(MaterialPageRoute(builder: (_) => const RegisterScreen()));
}

/// Khách bấm vào chức năng cần tài khoản: mời đăng nhập hoặc đăng ký (bảng trượt kiểu mẫu).
Future<void> requireLogin(BuildContext context, String action) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: RingIcon(Icons.lock_person_rounded, size: 120)),
            const SizedBox(height: 24),
            Text(
              tr('Cần đăng nhập'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Bạn cần đăng nhập để {0}.', [action]),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                goToLogin(context);
              },
              child: Text(tr('Đăng nhập')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(ctx);
                goToLogin(context, register: true);
              },
              child: Text(tr('Đăng ký')),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Để sau'))),
          ],
        ),
      ),
    ),
  );
}

/// Tab "Đăng nhập" của khách.
class GuestScreen extends StatelessWidget {
  const GuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Như màn "Settings" của mẫu: đầu trang ảnh có lời chào, các khối menu trắng có nhãn xám
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: navPillSpace(context)),
        children: [
          RcHero(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 22),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(tr('Chào bạn'), style: kText(22, FontWeight.w400, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('Bạn đang xem với tư cách khách'),
                  style: kText(12, FontWeight.w300, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RcCard(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('Đăng nhập để thuê đồ, đăng đồ cho thuê, xem hồ sơ người khác và quản lý ví.'),
                        textAlign: TextAlign.center,
                        style: kText(14, FontWeight.w300, lh: 21, color: AppColors.muted),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: () => goToLogin(context), child: Text(tr('Đăng nhập'))),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => goToLogin(context, register: true),
                        child: Text(tr('Đăng ký tài khoản')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RcMenuGroup(
                  label: tr('Tuỳ chọn'),
                  children: [
                    RcMenuItem(
                      icon: Icons.translate_rounded,
                      title: tr('Ngôn ngữ'),
                      trailing: LanguageBadge(code: currentLanguage),
                      onTap: () => showLanguagePicker(
                        context,
                        rebuild: () => const MainShell(guest: true, initialIndex: MainShell.accountTab),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                RcMenuGroup(
                  label: tr('Trợ giúp và cài đặt'),
                  children: [
                    RcMenuItem(
                      icon: Icons.support_agent_rounded,
                      title: tr('Hỗ trợ'),
                      onTap: () => showSupportSheet(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
