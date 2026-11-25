import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import 'en.dart';

/// Đa ngôn ngữ: câu tiếng Việt trong code chính là khóa tra bản dịch.
///   Text(tr('Đơn thuê'))
///   Text(tr('Hủy đơn #{0}?', [r.id]))   // {0}, {1}... thay bằng tham số
///
/// Danh sách ngôn ngữ và bản dịch do quản trị viên quản lý ở trang "Ngôn ngữ" (AdminSite),
/// app tải qua API khi mở và lưu lại để dùng khi mất mạng. Không cần cập nhật app khi sửa bản dịch.
/// Thiếu bản dịch thì dùng bản tiếng Anh có sẵn trong app (en.dart, chỉ cho tiếng Anh), thiếu nữa thì giữ tiếng Việt.
class AppLanguage {
  final String code;
  final String name; // tên bằng chính ngôn ngữ đó
  final String flag;
  final int version;
  const AppLanguage(this.code, this.name, this.flag, [this.version = 0]);

  factory AppLanguage.fromJson(Map<String, dynamic> j) => AppLanguage(
        j['code'] as String,
        (j['name'] ?? j['code']) as String,
        (j['flag'] ?? '🌐') as String,
        (j['version'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'code': code, 'name': name, 'flag': flag, 'version': version};
}

const _vietnamese = AppLanguage('vi', 'Tiếng Việt', '🇻🇳');

/// Ngôn ngữ chọn được: tiếng Việt + các ngôn ngữ quản trị viên bật trên AdminSite.
List<AppLanguage> appLanguages = const [_vietnamese, AppLanguage('en', 'English', '🇬🇧')];

const _prefLanguage = 'language';
const _prefLanguages = 'languages';
String _prefPack(String code) => 'translations_$code';

/// Ngôn ngữ đang dùng; MaterialApp lắng nghe để đổi theo.
final appLocale = ValueNotifier<Locale>(const Locale('vi'));

String get currentLanguage => appLocale.value.languageCode;

AppLanguage get currentAppLanguage =>
    appLanguages.firstWhere((l) => l.code == currentLanguage, orElse: () => _vietnamese);

/// Bản dịch của ngôn ngữ đang dùng (tải từ API).
Map<String, String> _texts = const {};

/// Gọi khi mở app (trước runApp): đọc lựa chọn đã lưu, tải danh sách ngôn ngữ và bản dịch mới nhất.
Future<void> loadLanguage() async {
  SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }

  _readCachedLanguages(prefs);
  final code = prefs.getString(_prefLanguage) ?? 'vi';
  if (code == 'vi') return;

  _texts = _readCachedPack(prefs, code);
  appLocale.value = Locale(code);

  await _refreshLanguages(prefs);
  // Ngôn ngữ đã bị quản trị viên ẩn thì về tiếng Việt
  if (!appLanguages.any((l) => l.code == code)) {
    _texts = const {};
    appLocale.value = const Locale('vi');
    await prefs.setString(_prefLanguage, 'vi');
    return;
  }
  await _downloadPack(prefs, code);
}

/// Danh sách ngôn ngữ mới nhất cho màn hình chọn ngôn ngữ.
Future<List<AppLanguage>> fetchLanguages() async {
  try {
    await _refreshLanguages(await SharedPreferences.getInstance());
  } catch (_) {
    // Mất mạng: dùng danh sách đã lưu
  }
  return appLanguages;
}

/// Đổi ngôn ngữ: tải bản dịch trước rồi mới đổi để màn hình hiện đúng ngay.
Future<void> setLanguage(String code) async {
  final prefs = await SharedPreferences.getInstance();
  if (code != 'vi') {
    _texts = _readCachedPack(prefs, code);
    await _downloadPack(prefs, code);
  } else {
    _texts = const {};
  }
  await prefs.setString(_prefLanguage, code);
  appLocale.value = Locale(code);
}

String tr(String vi, [List<Object?> args = const []]) {
  final code = currentLanguage;
  var text = code == 'vi' ? vi : (_texts[vi] ?? (code == 'en' ? en[vi] : null) ?? vi);
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return text;
}

void _readCachedLanguages(SharedPreferences prefs) {
  try {
    final raw = prefs.getString(_prefLanguages);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).map((e) => AppLanguage.fromJson(e as Map<String, dynamic>)).toList();
    appLanguages = [_vietnamese, ...list];
  } catch (_) {
    // Bản lưu hỏng: giữ danh sách mặc định
  }
}

Future<void> _refreshLanguages(SharedPreferences prefs) async {
  try {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/languages')).timeout(const Duration(seconds: 4));
    if (res.statusCode != 200) return;
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as List).map((e) => AppLanguage.fromJson(e as Map<String, dynamic>)).toList();
    appLanguages = [_vietnamese, ...list];
    await prefs.setString(_prefLanguages, jsonEncode(list.map((l) => l.toJson()).toList()));
  } catch (_) {
    // Mất mạng / Api chưa chạy: giữ danh sách hiện có
  }
}

Map<String, String> _readCachedPack(SharedPreferences prefs, String code) {
  try {
    final raw = prefs.getString(_prefPack(code));
    if (raw == null) return const {};
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return (j['texts'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
  } catch (_) {
    return const {};
  }
}

/// Tải bản dịch khi phiên bản trên máy chủ khác bản đã lưu.
Future<void> _downloadPack(SharedPreferences prefs, String code) async {
  try {
    final serverVersion = appLanguages.where((l) => l.code == code).map((l) => l.version).firstOrNull;
    final raw = prefs.getString(_prefPack(code));
    if (raw != null && serverVersion != null && serverVersion != 0) {
      final cachedVersion = ((jsonDecode(raw) as Map<String, dynamic>)['version'] as num?)?.toInt();
      if (cachedVersion == serverVersion) return;
    }
    final res = await http
        .get(Uri.parse('$apiBaseUrl/api/languages/$code/translations'))
        .timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) return;
    final body = utf8.decode(res.bodyBytes);
    final j = jsonDecode(body) as Map<String, dynamic>;
    _texts = (j['texts'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String));
    await prefs.setString(_prefPack(code), body);
  } catch (_) {
    // Mất mạng: dùng bản đã lưu
  }
}
