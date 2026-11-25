import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../services/auth_service.dart';
import '../services/config_service.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// Màn chào (mẫu "Splash Screen"): logo + chữ RENTMATE giữa màn hình trắng.
/// Trong lúc hiện, tải ngôn ngữ và cài đặt hệ thống (mất mạng thì dùng bản đã lưu).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Hiện logo ít nhất 1 giây cho khỏi chớp
    final results = await Future.wait([
      loadLanguage(),
      AppConfig.load(),
      AuthService().getUserId(),
      SharedPreferences.getInstance(),
      Future.delayed(const Duration(milliseconds: 1000)),
    ]);
    if (!mounted) return;
    final userId = results[2] as String?;
    final prefs = results[3] as SharedPreferences;

    // Kiểm tra userId (lưu cùng token khi đăng nhập): phiên cũ chưa có userId sẽ phải đăng nhập lại.
    final Widget next = userId != null
        ? const MainShell()
        : (prefs.getBool(onboardingDoneKey) ?? false)
        ? const LoginScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 84),
            SizedBox(height: 28),
            Text(
              'RENTMATE',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 5, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
