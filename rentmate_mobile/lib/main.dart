import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'l10n/l10n.dart';
import 'services/config_service.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
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
  // Tải ngôn ngữ và cài đặt hệ thống (từ AdminSite) trước khi hiện app; mất mạng thì dùng bản đã lưu
  Future.wait([loadLanguage(), AppConfig.load()]).then((_) => runApp(const RentMateApp()));
}

// Bảng màu "xanh rừng + kem": nền kem ấm, xanh đậm làm màu chính, xanh chanh làm điểm nhấn.
const brandColor = Color(0xFF1F4D3A);
const brandDark = Color(0xFF12301F);
const brandAccent = Color(0xFFD7EE7E);
const creamBg = Color(0xFFF6F3EC);
const inkColor = Color(0xFF1B1F1C);

class RentMateApp extends StatelessWidget {
  const RentMateApp({super.key});

  ThemeData _theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      primary: brandColor,
      onPrimary: Colors.white,
      secondary: brandDark,
      tertiary: brandAccent,
      surface: Colors.white,
    );
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
    // Be Vietnam Pro: font thiết kế riêng cho tiếng Việt; tiêu đề lớn dùng Playfair Display (serif)
    final text = GoogleFonts.beVietnamProTextTheme().apply(bodyColor: inkColor, displayColor: inkColor);
    final serif = GoogleFonts.playfairDisplayTextTheme();
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: creamBg,
      textTheme: text.copyWith(
        displaySmall: serif.displaySmall?.copyWith(color: inkColor, fontWeight: FontWeight.w700),
        headlineMedium: serif.headlineMedium?.copyWith(color: inkColor, fontWeight: FontWeight.w700),
        headlineSmall: serif.headlineSmall?.copyWith(color: inkColor, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: creamBg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: inkColor),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFE8E3D6)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE8E3D6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: brandColor, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: pill,
          textStyle: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: pill,
          foregroundColor: brandColor,
          side: const BorderSide(color: brandColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: brandColor)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: brandAccent,
          selectedForegroundColor: brandDark,
          side: const BorderSide(color: Color(0xFFE8E3D6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brandDark,
        indicatorColor: brandAccent,
        height: 68,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? brandDark : Colors.white70,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => GoogleFonts.beVietnamPro(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: states.contains(WidgetState.selected) ? Colors.white : Colors.white60,
            )),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: const BorderSide(color: Color(0xFFE8E3D6)),
        backgroundColor: Colors.white,
        selectedColor: brandAccent,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: brandColor,
        indicatorColor: brandColor,
        dividerColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brandAccent,
        foregroundColor: brandDark,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: brandDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

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
      theme: _theme(),
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
      // Kiểm tra userId (lưu cùng token khi đăng nhập): phiên cũ chưa có userId sẽ phải đăng nhập lại.
      home: FutureBuilder<String?>(
        future: AuthService().getUserId(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snap.data == null ? const LoginScreen() : const MainShell();
        },
      ),
    ),
    );
  }
}
