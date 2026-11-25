import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Giao diện theo mẫu Behance "Rentcars" (rentmate_mobile/design/behance-car):
// đen trắng tối giản, nền xám nhạt, khối trắng bo tròn lớn, nút đen dạng viên thuốc.
// Font gốc Urbanist không có bộ tiếng Việt nên dùng Lexend (cùng kiểu chữ tròn, mảnh).
class AppColors {
  static const primary = Color(0xFF0B0B0C); // đen: nút chính, mục đang chọn
  static const primaryDark = Color(0xFF000000);
  // Nền hồng xám rất nhạt của vòng tròn icon (mẫu: màn Settings)
  static const tint = Color(0xFFF3EFEF);
  static const background = Color(0xFFEBECEE); // nền xám của thân trang
  static const surface = Colors.white; // khối trắng
  static const ink = Color(0xFF111214); // chữ chính
  static const muted = Color(0xFF8B8E95); // chữ phụ: "Planning Your Break?", "View all"
  static const hint = Color(0xFF9EA1A8);
  static const border = Color(0xFFE4E5E8);
  static const divider = Color(0xFFEFF0F2);
  static const field = Color(0xFFF4F5F6); // nền ô nhập trong khối trắng, khung ảnh
  static const segment = Color(0xFFF4F5F6); // dải ngày đã chọn trên lịch
  static const heroTop = Color(0xFF55606E); // đầu trang tối (thay ảnh chụp của mẫu)
  static const heroBottom = Color(0xFF15171B);
  static const error = Color(0xFFE5484D);
  static const errorBg = Color(0xFFFFF1F1);
  static const success = Color(0xFF2FA36B);
  static const warning = Color(0xFFE08A00);
  static const info = Color(0xFF3A6FD8);
  static const star = Color(0xFF111214);
}

// Tên app hiện ở đầu Trang chủ, menu ☰ và giới thiệu (tên tiếng Anh, đổi ở đây là đổi toàn app)
const String appName = 'RentMate';

// Lề trái phải của mọi màn hình (mẫu: 16)
const double pagePadding = 16;

// Bo góc khối trắng (mẫu: ~22)
const double cardRadius = 22;

TextStyle _lexend({double? size, FontWeight? weight, Color? color}) =>
    GoogleFonts.lexend(fontSize: size, fontWeight: weight, color: color);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.tint,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.ink,
    secondaryContainer: AppColors.tint,
    onSecondaryContainer: AppColors.ink,
    surface: Colors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.border,
    outlineVariant: AppColors.divider,
    error: AppColors.error,
  );

  // Mẫu dùng chữ mảnh: thân 300, tiêu đề 400, số tiền/nhấn mạnh 600
  final base = GoogleFonts.lexendTextTheme().apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);
  final text = base.copyWith(
    headlineMedium: base.headlineMedium?.copyWith(fontSize: 26, fontWeight: FontWeight.w500),
    headlineSmall: base.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w400),
    titleLarge: base.titleLarge?.copyWith(fontSize: 19, fontWeight: FontWeight.w400),
    titleMedium: base.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
    titleSmall: base.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
    bodyLarge: base.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w300),
    bodyMedium: base.bodyMedium?.copyWith(fontSize: 14, fontWeight: FontWeight.w300),
    bodySmall: base.bodySmall?.copyWith(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.muted),
    labelLarge: base.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
  );

  final pill = BorderRadius.circular(30);
  // Mẫu "My Information": ô nhập dạng viên thuốc bo tròn hẳn, viền xám rất nhạt
  final fieldRadius = BorderRadius.circular(28);
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: color, width: width),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: text,
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.ink,
      titleTextStyle: _lexend(size: 19, weight: FontWeight.w400, color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
    ),
    // Ô nhập: nền trắng dạng viên thuốc, viền rất nhạt; đang gõ viền đen; lỗi viền đỏ
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: _lexend(color: AppColors.hint, size: 14, weight: FontWeight.w300),
      labelStyle: _lexend(color: AppColors.muted, weight: FontWeight.w300),
      helperStyle: _lexend(color: AppColors.muted, size: 12, weight: FontWeight.w300),
      errorStyle: _lexend(color: AppColors.error, size: 12, weight: FontWeight.w300),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      disabledBorder: border(AppColors.divider),
      focusedBorder: border(AppColors.ink, 1.2),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.2),
    ),
    // Nút chính: đen, dạng viên thuốc (mẫu: "Search", "View Details")
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: pill),
        textStyle: _lexend(size: 15, weight: FontWeight.w400),
        elevation: 0,
        disabledBackgroundColor: const Color(0xFFC9CBD0),
        disabledForegroundColor: Colors.white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: pill),
        textStyle: _lexend(size: 15, weight: FontWeight.w400),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: pill),
        foregroundColor: AppColors.ink,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.border),
        textStyle: _lexend(size: 15, weight: FontWeight.w400),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: _lexend(size: 14, weight: FontWeight.w500),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: AppColors.ink)),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: const BorderSide(color: AppColors.hint, width: 1.5),
    ),
    radioTheme: const RadioThemeData(fillColor: WidgetStatePropertyAll(AppColors.primary)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    // Thanh tab: nền trắng bo tròn, tab đang chọn là viên thuốc đen chữ trắng
    tabBarTheme: TabBarThemeData(
      indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(22)),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: AppColors.muted,
      labelStyle: _lexend(size: 14, weight: FontWeight.w400),
      unselectedLabelStyle: _lexend(size: 14, weight: FontWeight.w300),
      dividerColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.muted,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: pill),
      ),
    ),
    // Chip: viên thuốc trắng, đang chọn nền đen chữ trắng
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: pill),
      side: BorderSide.none,
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      labelStyle: _lexend(size: 13, weight: FontWeight.w300, color: AppColors.ink),
      secondaryLabelStyle: _lexend(size: 13, weight: FontWeight.w400, color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    // Bảng trượt từ dưới lên: góc trên bo 26, có thanh kéo xám
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Color(0xFFDADCE0),
      dragHandleSize: Size(40, 4),
      modalBarrierColor: Color(0x40000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
    ),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.ink),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: pill),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      contentTextStyle: _lexend(color: Colors.white, size: 14, weight: FontWeight.w300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
