import 'package:flutter/material.dart';

// Các mảnh giao diện dùng chung cho mọi màn hình.

/// Mở ảnh toàn màn hình, chụm 2 ngón để phóng to.
void showImageViewer(BuildContext context, String url) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: InteractiveViewer(
        maxScale: 4,
        child: Center(child: Image.network(url, fit: BoxFit.contain)),
      ),
    ),
  ));
}

/// Ảnh đại diện: có ảnh thì hiện ảnh, chưa có thì hiện chữ cái đầu của tên.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const UserAvatar({super.key, required this.name, this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: url == null ? null : NetworkImage(url!),
      child: url != null
          ? null
          : Text(trimmed.isEmpty ? '?' : trimmed.split(' ').last.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.bold)),
    );
  }
}

/// "Exception: abc" -> "abc"
String errorText(Object e) => e.toString().replaceFirst('Exception: ', '');

void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Đồng ý',
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return ok == true;
}

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) {
  final l = d.toLocal();
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

String fmtDateTime(DateTime d) {
  // Server trả giờ UTC nhưng có thể thiếu chữ "Z"
  final utc = d.isUtc ? d : DateTime.utc(d.year, d.month, d.day, d.hour, d.minute, d.second);
  final l = utc.toLocal();
  return '${two(l.hour)}:${two(l.minute)} ${two(l.day)}/${two(l.month)}/${l.year}';
}

/// Giống quy tắc mật khẩu mặc định của ASP.NET Identity bên server.
String? passwordError(String? v) {
  if (v == null || v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Cần ít nhất 1 chữ hoa';
  if (!RegExp(r'[a-z]').hasMatch(v)) return 'Cần ít nhất 1 chữ thường';
  if (!RegExp(r'\d').hasMatch(v)) return 'Cần ít nhất 1 chữ số';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return 'Cần ít nhất 1 ký tự đặc biệt (vd. @ # !)';
  return null;
}

String? phoneError(String? v) {
  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
  if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) return 'Số điện thoại gồm 10 số, bắt đầu bằng 0';
  return null;
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn hình trống; đặt trong ListView để vẫn kéo xuống làm mới được.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Nhãn trạng thái nhỏ có màu.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

// Màu nhãn theo trạng thái (đơn thuê, đồ, giao dịch ví).
Color statusColor(String status) => switch (status) {
      'Pending' || 'PendingApproval' || 'Approved' => const Color(0xFFE08A00),
      'WaitingForPickup' || 'Rented' => const Color(0xFF2563EB),
      'Available' || 'Completed' || 'Returned' => const Color(0xFF16A34A),
      'Rejected' || 'Cancelled' || 'Overdue' || 'Unavailable' => const Color(0xFFDC2626),
      _ => const Color(0xFF6B7280),
    };

/// Ảnh đại diện cho đồ. Có ảnh thì hiện ảnh; chưa có ảnh (hoặc tải lỗi) thì hiện
/// ô màu + biểu tượng theo tên danh mục.
class ItemThumb extends StatelessWidget {
  final String categoryName;
  final String? imageUrl;
  final double size;
  final double radius;
  const ItemThumb({super.key, required this.categoryName, this.imageUrl, this.size = 64, this.radius = 14});

  static const _palette = [
    Color(0xFF0E9F8E),
    Color(0xFF2563EB),
    Color(0xFF9333EA),
    Color(0xFFE08A00),
    Color(0xFFDB2777),
    Color(0xFF0891B2),
  ];

  static IconData iconFor(String category) {
    final c = category.toLowerCase();
    if (c.contains('điện thoại') || c.contains('phone')) return Icons.smartphone_rounded;
    if (c.contains('laptop') || c.contains('máy tính')) return Icons.laptop_mac_rounded;
    if (c.contains('tai nghe') || c.contains('loa') || c.contains('âm thanh')) return Icons.headphones_rounded;
    if (c.contains('máy ảnh') || c.contains('camera') || c.contains('quay')) return Icons.photo_camera_rounded;
    if (c.contains('điện tử')) return Icons.devices_other_rounded;
    if (c.contains('xe') || c.contains('đạp')) return Icons.pedal_bike_rounded;
    if (c.contains('du lịch') || c.contains('cắm trại') || c.contains('lều')) return Icons.forest_rounded;
    if (c.contains('thể thao')) return Icons.sports_soccer_rounded;
    if (c.contains('quần') || c.contains('áo') || c.contains('thời trang') || c.contains('váy')) return Icons.checkroom_rounded;
    if (c.contains('sách')) return Icons.menu_book_rounded;
    if (c.contains('nhà') || c.contains('gia dụng') || c.contains('bếp')) return Icons.kitchen_rounded;
    if (c.contains('dụng cụ') || c.contains('công cụ') || c.contains('khoan')) return Icons.handyman_rounded;
    if (c.contains('game') || c.contains('trò chơi')) return Icons.sports_esports_rounded;
    return Icons.inventory_2_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return _placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Ảnh nhỏ thì giải mã ở cỡ nhỏ cho nhẹ máy
        cacheWidth: size.isFinite && size < 400 ? (size * 3).round() : null,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (_, child, progress) => progress == null ? child : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    final color = _palette[categoryName.hashCode.abs() % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.32)],
        ),
      ),
      child: Icon(iconFor(categoryName), color: color, size: size * 0.45),
    );
  }
}

/// Dòng "nhãn ........ giá trị".
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: muted)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: valueColor,
                fontSize: bold ? 16 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp ghi chú (thông tin / cảnh báo / lỗi).
class NoticeBox extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const NoticeBox(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color = const Color(0xFF2563EB)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.95), height: 1.35))),
        ],
      ),
    );
  }
}

/// Nút chính có vòng xoay khi đang gửi.
class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const BusyButton({super.key, required this.busy, required this.onPressed, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(label);
    if (icon != null && !busy) {
      return FilledButton.icon(onPressed: onPressed, icon: Icon(icon), label: child);
    }
    return FilledButton(onPressed: busy ? null : onPressed, child: child);
  }
}
