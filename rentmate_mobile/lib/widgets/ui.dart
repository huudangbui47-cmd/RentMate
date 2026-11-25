import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/l10n.dart';
import '../services/item_service.dart';
import '../theme.dart';

// Các mảnh giao diện dùng chung cho mọi màn hình (theo bộ mẫu Housely).

/// Ô nhập tiền: chỉ nhận số và tự thêm dấu chấm hàng nghìn khi gõ (6000 -> 6.000).
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = moneyText(num.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// 6000 -> "6.000" (không kèm đơn vị, dùng cho ô nhập tiền).
String moneyText(num value) {
  final s = value.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Đọc số từ ô nhập tiền đã có dấu chấm ("6.000" -> 6000).
num? parseMoney(String? text) => num.tryParse((text ?? '').replaceAll('.', ''));

/// Mở ảnh toàn màn hình, chụm 2 ngón để phóng to.
void showImageViewer(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: InteractiveViewer(
          maxScale: 4,
          child: Center(child: Image.network(url, fit: BoxFit.contain)),
        ),
      ),
    ),
  );
}

/// Ảnh đại diện: có ảnh thì hiện ảnh, chưa có thì hiện chữ cái đầu của tên.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double radius;
  const UserAvatar({super.key, required this.name, this.url, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.tint,
      foregroundColor: AppColors.primary,
      backgroundImage: url == null ? null : NetworkImage(url!),
      child: url != null
          ? null
          : Text(
              trimmed.isEmpty ? '?' : trimmed.split(' ').last.characters.first.toUpperCase(),
              style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600),
            ),
    );
  }
}

/// "Exception: abc" -> "abc"
/// Câu lỗi từ server là tiếng Việt; quản trị viên thêm câu đó ở trang Ngôn ngữ thì app hiện bản dịch.
String errorText(Object e) => tr(e.toString().replaceFirst('Exception: ', ''));

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Hộp xác nhận kiểu mẫu (ảnh "Delete"): bảng trượt từ dưới lên, icon tròn, câu hỏi và 2 nút.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmText,
  bool danger = false,
  IconData? icon,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RingIcon(icon ?? (danger ? Icons.delete_rounded : Icons.help_rounded), size: 120),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.segment, foregroundColor: AppColors.ink),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(tr('Thôi')),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(confirmText ?? tr('Đồng ý'), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return ok == true;
}

/// Bảng trượt từ dưới lên có tiêu đề căn giữa (kiểu "Fillter", "Select Date" của mẫu).
Future<T?> showAppSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// Bảng báo thành công (kiểu "Reserve Success"): icon tròn, tiêu đề, mô tả, nút.
Future<void> showSuccessSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String buttonText,
  IconData icon = Icons.check_rounded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RingIcon(icon, size: 190),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.45),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(buttonText)),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Chọn chụp ảnh hay lấy từ thư viện (bảng kiểu mẫu "Gallery").
Future<ImageSource?> pickImageSource(BuildContext context, {String? galleryLabel}) {
  Widget row(BuildContext ctx, IconData icon, String label, ImageSource source) => InkWell(
    onTap: () => Navigator.pop(ctx, source),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: pagePadding, vertical: 10),
      child: Row(
        children: [
          IconCircle(icon, size: 48),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        ],
      ),
    ),
  );
  return showAppSheet<ImageSource>(
    context,
    title: tr('Thêm ảnh'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(ctx, Icons.photo_camera_outlined, tr('Chụp ảnh'), ImageSource.camera),
          row(ctx, Icons.photo_library_outlined, galleryLabel ?? tr('Chọn từ thư viện'), ImageSource.gallery),
        ],
      ),
    ),
  );
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
  if (v == null || v.length < 6) return tr('Mật khẩu tối thiểu 6 ký tự');
  if (!RegExp(r'[A-Z]').hasMatch(v)) return tr('Cần ít nhất 1 chữ hoa');
  if (!RegExp(r'[a-z]').hasMatch(v)) return tr('Cần ít nhất 1 chữ thường');
  if (!RegExp(r'\d').hasMatch(v)) return tr('Cần ít nhất 1 chữ số');
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(v)) return tr('Cần ít nhất 1 ký tự đặc biệt (vd. @ # !)');
  return null;
}

String? phoneError(String? v) {
  if (v == null || v.trim().isEmpty) return tr('Vui lòng nhập số điện thoại');
  if (!RegExp(r'^0\d{9}$').hasMatch(v.trim())) return tr('Số điện thoại gồm 10 số, bắt đầu bằng 0');
  return null;
}

// =========================
// KHỐI GIAO DIỆN CƠ BẢN
// =========================

/// Icon lớn trong 2 vòng tròn (thay cho hình minh họa của mẫu: màn trống, thành công, xác nhận).
class RingIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  const RingIcon(this.icon, {super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.09),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), shape: BoxShape.circle),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: Icon(icon, size: size * 0.34, color: AppColors.ink),
      ),
    );
  }
}

/// Icon trong vòng tròn nền nhạt (đầu dòng thông báo, phương thức thanh toán...).
class IconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color background;
  const IconCircle(
    this.icon, {
    super.key,
    this.size = 40,
    this.color = AppColors.ink,
    this.background = AppColors.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Nút tròn có viền (chuông, chat ở đầu trang chủ).
class CircleIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  const CircleIconButton({super.key, required this.icon, this.onPressed, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
        ),
      ),
    );
  }
}

/// Tiêu đề trang đăng nhập/đăng ký (mẫu "Welcome Back !"): chữ lớn đậm và dòng mô tả xám.
class PageHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const PageHeading(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400, height: 1.25)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w300, height: 1.45),
          ),
        ],
      ],
    );
  }
}

/// Tiêu đề một khối nội dung (mẫu "Recommended ..... See all").
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  const SectionTitle(this.title, {super.key, this.actionText, this.onAction, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w400)),
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w300, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ô nhập có nhãn đậm phía trên (mẫu: "Email" rồi tới ô nhập).
class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const LabeledField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nhãn xám mảnh nằm trên ô như mẫu ("First Name", "Last Name")
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Ô mật khẩu có nút ẩn/hiện (icon mắt gạch như mẫu).
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? action;
  const PasswordField({
    super.key,
    required this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.onSubmitted,
    this.action,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hide = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hide,
      textInputAction: widget.action,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _hide = !_hide),
        ),
      ),
    );
  }
}

/// Thanh tab kiểu mẫu (My Booking): nền xám bo góc, tab đang chọn là khối màu chính.
class SegmentTabs extends StatelessWidget implements PreferredSizeWidget {
  final List<String> labels;
  final TabController? controller;
  final EdgeInsetsGeometry margin;
  const SegmentTabs(
    this.labels, {
    super.key,
    this.controller,
    this.margin = const EdgeInsets.fromLTRB(pagePadding, 4, pagePadding, 12),
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: TabBar(
        controller: controller,
        tabs: [for (final l in labels) Tab(text: l, height: 40)],
      ),
    );
  }
}

/// Giá kiểu mẫu: "$310" đậm màu chính + "/month" xám.
class PriceText extends StatelessWidget {
  final String amount;
  final String? unit;
  final double fontSize;
  final Color color;
  const PriceText(this.amount, {super.key, this.unit, this.fontSize = 15, this.color = AppColors.ink});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: amount,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: fontSize, color: color),
          ),
          if (unit != null)
            TextSpan(
              text: unit,
              style: TextStyle(color: AppColors.muted, fontSize: fontSize - 3, fontWeight: FontWeight.w300),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Dòng có icon ghim + chữ xám (địa chỉ, khu vực).
class LocationText extends StatelessWidget {
  final String text;
  final double fontSize;
  const LocationText(this.text, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: fontSize + 4, color: AppColors.muted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.muted, fontSize: fontSize),
          ),
        ),
      ],
    );
  }
}

/// Dòng đồ trong danh sách (mẫu "Popular", "My Booking"): ảnh 80x62 bo 10, tên, dòng phụ, dòng dưới.
class ItemRow extends StatelessWidget {
  final Widget thumb;
  final String title;
  final Widget? subtitle;
  final Widget? bottom;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  const ItemRow({
    super.key,
    required this.thumb,
    required this.title,
    this.subtitle,
    this.bottom,
    this.trailing,
    this.onTap,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: divider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              )
            : null,
        child: Row(
          children: [
            thumb,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                        ),
                      ),
                      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                    ],
                  ),
                  if (subtitle != null) ...[const SizedBox(height: 6), subtitle!],
                  if (bottom != null) ...[const SizedBox(height: 8), bottom!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung có viền bo 12 (thẻ đồ ở đầu màn Đặt thuê, ô chọn phương thức...).
class OutlineBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;
  final VoidCallback? onTap;
  const OutlineBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Dòng menu kiểu mẫu (Profile): icon viền màu chính, chữ, mũi tên.
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const MenuRow({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconCircle(icon, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ],
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.ink, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Dòng thao tác dưới một đơn (mẫu "Write review", "Call Agent"): icon màu chính + chữ xám.
class ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const ActionRow({super.key, required this.icon, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, color: onTap == null ? AppColors.border : c, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color ?? (onTap == null ? AppColors.border : AppColors.ink),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Ô tích vuông bo góc (mẫu "Fillter").
class TickBox extends StatelessWidget {
  final bool selected;
  const TickBox({super.key, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: 1.5),
      ),
      child: selected ? const Icon(Icons.check_rounded, size: 18, color: Colors.white) : null,
    );
  }
}

/// Khung viền đứt (mẫu "Click here to upload").
class DashedBox extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  const DashedBox({super.key, required this.child, this.onTap, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, (d + 5).clamp(0, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo RentMate (màn chào, đăng nhập): ghim bo tròn màu chính, giữa có biểu tượng bắt tay.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(size / 2),
              topRight: Radius.circular(size / 2),
              bottomLeft: Radius.circular(size / 2),
              bottomRight: Radius.circular(size * 0.12),
            ),
          ),
          child: Icon(Icons.handshake_rounded, color: Colors.white, size: size * 0.5),
        ),
        SizedBox(height: size * 0.12),
        // Bóng mờ dưới logo như mẫu
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            width: size * 0.7,
            height: size * 0.1,
            decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(size)),
          ),
        ),
      ],
    );
  }
}

// =========================
// TRẠNG THÁI: ĐANG TẢI / LỖI / TRỐNG
// =========================

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RingIcon(Icons.cloud_off_rounded, size: 130),
            const SizedBox(height: 24),
            Text(
              tr('Không tải được dữ liệu'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w400),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('Thử lại')),
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn hình trống (mẫu "No notification yet"); đặt trong ListView để vẫn kéo xuống làm mới được.
class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 56, 32, 32),
      child: Column(
        children: [
          RingIcon(icon, size: 150),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w400),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.45),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 24), action!],
        ],
      ),
    );
  }
}

/// Nhãn trạng thái (mẫu "Waiting payment", "Checkin"): nền nhạt bo tròn, chữ cùng màu.
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  const StatusBadge(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFF1F2F4), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w400, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// Màu nhãn theo trạng thái (đơn thuê, đồ, giao dịch ví).
Color statusColor(String status) => switch (status) {
  'Pending' || 'PendingApproval' || 'Approved' || 'DamageClaimed' => AppColors.warning,
  'WaitingForPickup' || 'Rented' => AppColors.info,
  'Available' || 'Completed' || 'Returned' => AppColors.success,
  'Rejected' || 'Cancelled' || 'Overdue' || 'Unavailable' || 'Disputed' => AppColors.error,
  _ => AppColors.muted,
};

/// Ảnh đại diện cho đồ. Có ảnh thì hiện ảnh; chưa có ảnh (hoặc tải lỗi) thì hiện
/// ô xám nhạt + biểu tượng theo danh mục.
class ItemThumb extends StatelessWidget {
  final String categoryName;
  final String? imageUrl;
  final double size;
  final double? height;
  final double radius;
  const ItemThumb({
    super.key,
    required this.categoryName,
    this.imageUrl,
    this.size = 64,
    this.height,
    this.radius = 10,
  });

  /// Icon theo lựa chọn của quản trị viên (CategoryIconOption trên Api); chưa chọn thì đoán theo tên.
  static const _iconByKey = <String, IconData>{
    'smartphone': Icons.smartphone_rounded,
    'laptop': Icons.laptop_mac_rounded,
    'headphones': Icons.headphones_rounded,
    'camera': Icons.photo_camera_rounded,
    'devices': Icons.devices_other_rounded,
    'game': Icons.sports_esports_rounded,
    'bike': Icons.pedal_bike_rounded,
    'motorbike': Icons.two_wheeler_rounded,
    'car': Icons.directions_car_rounded,
    'camping': Icons.forest_rounded,
    'sports': Icons.sports_soccer_rounded,
    'fashion': Icons.checkroom_rounded,
    'book': Icons.menu_book_rounded,
    'kitchen': Icons.kitchen_rounded,
    'tools': Icons.handyman_rounded,
    'music': Icons.music_note_rounded,
    'baby': Icons.child_friendly_rounded,
    'party': Icons.celebration_rounded,
    'furniture': Icons.chair_rounded,
    'other': Icons.inventory_2_rounded,
  };

  static IconData iconFor(String category) {
    final c = category.toLowerCase();
    final chosen = _iconByKey[categoryIconKeys[c]];
    if (chosen != null) return chosen;
    if (c.contains('điện thoại') || c.contains('phone')) return Icons.smartphone_rounded;
    if (c.contains('laptop') || c.contains('máy tính')) return Icons.laptop_mac_rounded;
    if (c.contains('tai nghe') || c.contains('loa') || c.contains('âm thanh')) return Icons.headphones_rounded;
    if (c.contains('máy ảnh') || c.contains('camera') || c.contains('quay')) return Icons.photo_camera_rounded;
    if (c.contains('điện tử')) return Icons.devices_other_rounded;
    if (c.contains('xe') || c.contains('đạp')) return Icons.pedal_bike_rounded;
    if (c.contains('du lịch') || c.contains('cắm trại') || c.contains('lều')) return Icons.forest_rounded;
    if (c.contains('thể thao')) return Icons.sports_soccer_rounded;
    if (c.contains('quần') || c.contains('áo') || c.contains('thời trang') || c.contains('váy')) {
      return Icons.checkroom_rounded;
    }
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
      child: Container(
        width: size,
        height: height ?? size,
        color: Colors.white,
        padding: const EdgeInsets.all(3),
        child: Image.network(
          imageUrl!,
          fit: BoxFit.contain, // ảnh món đồ luôn hiện trọn, không cắt
          // Ảnh nhỏ thì giải mã ở cỡ nhỏ cho nhẹ máy
          cacheWidth: size.isFinite && size < 400 ? (size * 3).round() : null,
          errorBuilder: (_, _, _) => _placeholder(),
          loadingBuilder: (_, child, progress) => progress == null ? child : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    final h = height ?? size;
    final iconSize = (size.isFinite ? (size < h ? size : h) : h) * 0.42;
    return Container(
      width: size,
      height: h,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius), color: const Color(0xFFF4F5F6)),
      child: Icon(iconFor(categoryName), color: const Color(0xFFA3A8B0), size: iconSize.isFinite ? iconSize : 40),
    );
  }
}

/// Dòng "nhãn ........ giá trị" (mẫu "Price Details"); bold = dòng Tổng, số tiền màu chính cỡ lớn.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: bold ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: bold ? AppColors.ink : AppColors.muted,
              fontWeight: bold ? FontWeight.w500 : FontWeight.w300,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                color: valueColor ?? (bold ? AppColors.primary : AppColors.ink),
                fontSize: bold ? 20 : 14,
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
  const NoticeBox(this.text, {super.key, this.icon = Icons.info_outline_rounded, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, height: 1.4, fontSize: 13.5)),
          ),
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

/// Thanh dưới cùng chứa nút chính (mẫu "Rent now", "Confirm and Pay").
class BottomActionBar extends StatelessWidget {
  final Widget child;
  const BottomActionBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 16), child: child),
    );
  }
}
