import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme.dart';
import 'ui.dart';
import 'kit.dart';

/// Chọn ngôn ngữ (danh sách do quản trị viên bật trên AdminSite).
/// Đổi xong dựng lại màn hình hiện tại ([rebuild]) để mọi chữ đổi theo.
Future<void> showLanguagePicker(BuildContext context, {required Widget Function() rebuild}) async {
  final code = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: FutureBuilder<List<AppLanguage>>(
        future: fetchLanguages(),
        initialData: appLanguages,
        builder: (context, snap) {
          final languages = snap.data ?? appLanguages;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Ngôn ngữ'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(minHeight: 2),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: pagePadding),
                  children: [
                    for (final l in languages)
                      InkWell(
                        onTap: () => Navigator.pop(context, l.code),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Text(l.flag, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 14),
                              Expanded(child: Text(l.name, style: const TextStyle(fontSize: 16))),
                              TickBox(selected: l.code == currentLanguage),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    ),
  );
  if (code == null || code == currentLanguage || !context.mounted) return;

  // Tải bản dịch có thể mất 1-2 giây
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  await setLanguage(code);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => rebuild()), (_) => false);
}

/// Nút quả địa cầu + mã ngôn ngữ, đặt ở góc màn hình đăng nhập / khách.
class LanguageButton extends StatelessWidget {
  final Widget Function() rebuild;
  const LanguageButton({super.key, required this.rebuild});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: const Icon(Icons.language, size: 20),
      label: Text(currentLanguage.toUpperCase()),
      onPressed: () => showLanguagePicker(context, rebuild: rebuild),
    );
  }
}

/// Nút cờ tròn kính mờ (góc phải đầu trang): chạm để đổi qua lại Tiếng Việt / English.
class FlagToggleButton extends StatelessWidget {
  final Widget Function() rebuild;
  const FlagToggleButton({super.key, required this.rebuild});

  Future<void> _toggle(BuildContext context) async {
    final code = currentLanguage == 'vi' ? 'en' : 'vi';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
    await setLanguage(code);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => rebuild()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: currentLanguage == 'vi' ? 'Switch to English' : 'Chuyển sang Tiếng Việt',
      child: GestureDetector(onTap: () => _toggle(context), child: RcFlag(currentLanguage, size: 34)),
    );
  }
}
