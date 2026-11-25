import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Chọn ngôn ngữ (danh sách do quản trị viên bật trên AdminSite).
/// Đổi xong dựng lại màn hình hiện tại ([rebuild]) để mọi chữ đổi theo.
Future<void> showLanguagePicker(BuildContext context, {required Widget Function() rebuild}) async {
  final code = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: FutureBuilder<List<AppLanguage>>(
        future: fetchLanguages(),
        initialData: appLanguages,
        builder: (context, snap) {
          final languages = snap.data ?? appLanguages;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(tr('Ngôn ngữ'), style: Theme.of(context).textTheme.titleLarge),
              ),
              if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(minHeight: 2),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final l in languages)
                      ListTile(
                        leading: Text(l.flag, style: const TextStyle(fontSize: 26)),
                        title: Text(l.name),
                        trailing: l.code == currentLanguage
                            ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                            : null,
                        onTap: () => Navigator.pop(context, l.code),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
