import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/l10n.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';

import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() {
  // API trả 401 (token hết hạn / tài khoản bị khóa / đổi mật khẩu ở máy khác): đăng xuất và về màn hình đăng nhập
  var redirecting = false;
  onSessionExpired = () async {
    if (redirecting) return;
    redirecting = true;
    await AuthService().logout();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen(sessionExpired: true)),
      (_) => false,
    );
    redirecting = false;
  };
  WidgetsFlutterBinding.ensureInitialized();
  // Màn chào (SplashScreen) tải ngôn ngữ và cài đặt hệ thống rồi mới vào app
  runApp(const RentMateApp());
}

class RentMateApp extends StatelessWidget {
  const RentMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Đổi ngôn ngữ thì dựng lại toàn bộ app
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => MaterialApp(
        title: 'RentMate',
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        // Chữ có sẵn của Flutter (lịch, nút Hủy/OK...): ngôn ngữ Flutter chưa hỗ trợ thì dùng tiếng Anh
        locale: GlobalMaterialLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
        supportedLocales: {
          const Locale('vi'),
          GlobalMaterialLocalizations.delegate.isSupported(locale) ? locale : const Locale('en'),
        }.toList(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Mặc định chữ thanh trạng thái màu tối (nền xám); đầu trang ảnh tự đổi sang trắng
        builder: (context, child) =>
            AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.dark, child: child!),
        home: const SplashScreen(),
      ),
    );
  }
}
