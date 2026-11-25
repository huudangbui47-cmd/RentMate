import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'ui.dart';
import '../services/banner_service.dart';
import '../services/config_service.dart';
import '../services/item_service.dart';
import '../services/auth_service.dart';
import '../services/favorite_service.dart';
import '../screens/guest_screen.dart';
import '../l10n/l10n.dart';

// Các khối dùng chung theo mẫu Behance "Rentcars": đầu trang tối bo tròn đáy, ô tìm kiếm kính mờ,
// khối trắng bo 22 trên nền xám, vòng tròn icon nền hồng xám, nút đen viên thuốc, thanh điều hướng nổi.

/// Kiểu chữ Lexend: [size]/[weight], khoảng cách dòng [lh] (px), giãn chữ theo % cỡ chữ.
TextStyle kText(
  double size,
  FontWeight weight, {
  double? lh,
  Color color = AppColors.ink,
  double tracking = 0,
  TextDecoration? decoration,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  height: lh == null ? null : lh / size,
  letterSpacing: size * tracking,
  color: color,
  decoration: decoration,
);

// Các kiểu chữ lặp lại nhiều trong mẫu
final kTitle = kText(19, FontWeight.w400, lh: 23); // tiêu đề mục: "Top trends"
final kTitle15 = kText(16, FontWeight.w400, lh: 22); // tiêu đề nhỏ, tiêu đề thanh trên
final kViewAll = kText(14, FontWeight.w300, color: AppColors.muted); // "View all"
final kBody12Hint = kText(12, FontWeight.w300, lh: 18, color: AppColors.muted);
final kSub12 = kText(11, FontWeight.w300, lh: 14, color: AppColors.muted); // "Planning Your Break?"

/// Icon SVG trong assets/icons/[name].svg. Truyền [color] để tô lại màu.
class KitIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const KitIcon(this.name, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? AppColors.ink, BlendMode.srcIn),
    );
  }
}

/// Nút đen viên thuốc (mẫu: "Search", "View Details"). [small] cho nút trong thẻ.
class KitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool small;
  final bool busy;
  final bool light; // nút trắng chữ đen (trên nền tối)
  const KitButton(this.label, {super.key, this.onPressed, this.small = false, this.busy = false, this.light = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final bg = light ? Colors.white : AppColors.primary;
    final fg = light ? AppColors.ink : Colors.white;
    return Material(
      color: enabled ? bg : const Color(0xFFC9CBD0),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: enabled ? onPressed : null,
        child: Padding(
          padding: small
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: busy
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                : Text(
                    label,
                    style: small
                        ? kText(12, FontWeight.w400, lh: 16, color: enabled ? fg : Colors.white)
                        : kText(15, FontWeight.w400, lh: 22, color: enabled ? fg : Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Đầu trang tối bo tròn đáy như mẫu. Có [images] (banner quản trị tải lên) thì làm nền ảnh chạy
/// lần lượt, phủ tối để chữ trắng dễ đọc; không có thì dùng nền chuyển màu tối. Tự chừa chỗ cho thanh trạng thái.
class RcHero extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final List<String>? images; // null: dùng banner chung do quản trị tải lên
  const RcHero({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(18, 8, 18, 18), this.images});

  @override
  Widget build(BuildContext context) {
    final list = images;
    if (list == null) {
      return ValueListenableBuilder<List<String>>(
        valueListenable: BannerCenter.banners,
        builder: (_, banners, _) => RcHero(padding: padding, images: banners, child: child),
      );
    }
    final top = MediaQuery.of(context).padding.top;
    // Chữ, icon thanh trạng thái màu trắng trên ảnh tối
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, -1),
                    radius: 1.4,
                    colors: [AppColors.heroTop, Color(0xFF2A2F37), AppColors.heroBottom],
                    stops: [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            if (list.isNotEmpty) ...[
              Positioned.fill(child: _BannerSlides(images: list)),
              // Phủ tối: đậm hơn ở trên (thanh trạng thái, tên app) và dưới (ô tìm kiếm)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x40000000), Color(0x8C000000)],
                      stops: [0, 0.5, 1],
                    ),
                  ),
                ),
              ),
            ],
            Padding(
              padding: padding.copyWith(top: padding.top + top),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.white),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ảnh banner chuyển lần lượt sau mỗi 5 giây (mờ dần sang ảnh sau), mỗi ảnh phóng to chậm cho có chuyển động.
class _BannerSlides extends StatefulWidget {
  final List<String> images;
  const _BannerSlides({required this.images});

  @override
  State<_BannerSlides> createState() => _BannerSlidesState();
}

class _BannerSlidesState extends State<_BannerSlides> {
  static const _interval = Duration(seconds: 5);
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _BannerSlides old) {
    super.didUpdateWidget(old);
    if (old.images.length != widget.images.length) {
      _index = 0;
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    if (widget.images.length < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      final next = (_index + 1) % widget.images.length;
      // Tải trước ảnh sau để lúc chuyển không bị nháy trống
      precacheImage(NetworkImage(widget.images[(next + 1) % widget.images.length]), context);
      setState(() {
        _index = next;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.images[_index % widget.images.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 900),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('$_index-$url'),
        tween: Tween(begin: 1.0, end: 1.08),
        duration: _interval + const Duration(seconds: 1),
        builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
        child: Image.network(
          url,
          fit: BoxFit.cover, // ảnh nền trang trí nên được cắt cho kín khung (khác ảnh món đồ)
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
      ),
    );
  }
}

/// Thanh trên của màn phụ theo mẫu "My Information" / "Deals": ảnh nền tối bo đáy,
/// mũi tên quay lại (icon trơn) · tiêu đề giữa · nút phải; chừa một dải ảnh bên dưới cho giống mẫu.
class RcHeroBar extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget? leading;
  final Widget? bottom; // vd. thanh tab, nằm trong phần ảnh
  final bool showBack;
  final double extra; // khoảng ảnh trống dưới tiêu đề
  const RcHeroBar({
    super.key,
    required this.title,
    this.trailing,
    this.leading,
    this.bottom,
    this.showBack = true,
    this.extra = 22,
  });

  /// Chiều cao (không tính thanh trạng thái) để dùng làm PreferredSize.
  static double heightFor({PreferredSizeWidget? bottom, double extra = 22}) =>
      6 + 48 + extra + (bottom == null ? 0 : bottom.preferredSize.height + 4);

  @override
  Widget build(BuildContext context) {
    final canPop = showBack && (ModalRoute.of(context)?.canPop ?? false);
    return RcHero(
      padding: EdgeInsets.fromLTRB(8, 6, 8, extra),
      child: Theme(
        // Nút trên nền ảnh tối: chữ, icon màu trắng
        data: Theme.of(context).copyWith(
          iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: Colors.white)),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: Colors.white)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child:
                        leading ??
                        (canPop
                            ? IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, size: 26),
                                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                                onPressed: () => Navigator.maybePop(context),
                              )
                            : null),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kText(22, FontWeight.w400, color: Colors.white),
                    ),
                  ),
                  // Ít nhất 56 cho cân với nút Back, rộng thêm nếu nút bên phải dài hơn (không tràn chữ)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 56),
                    child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: trailing),
                  ),
                ],
              ),
            ),
            if (bottom != null) ...[const SizedBox(height: 4), bottom!],
          ],
        ),
      ),
    );
  }
}

/// RcHeroBar dùng làm appBar của Scaffold (thay AppBar mặc định ở mọi màn phụ).
class RcAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  const RcAppBar({
    super.key,
    this.title,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(RcHeroBar.heightFor(bottom: bottom));

  @override
  Widget build(BuildContext context) {
    final t = title;
    return RcHeroBar(
      title: t is Text ? (t.data ?? '') : '',
      leading: leading,
      showBack: automaticallyImplyLeading,
      trailing: actions == null || actions!.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: actions!),
      bottom: bottom,
    );
  }
}

/// Cờ tròn đầy (không viền, không nền) cho ngôn ngữ: vi, en.
class RcFlag extends StatelessWidget {
  final String code;
  final double size;
  const RcFlag(this.code, {super.key, this.size = 34});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SvgPicture.asset(
        'assets/icons/flag_${code == 'vi' ? 'vi' : 'en'}.svg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// Ô tìm kiếm kính mờ trên đầu trang tối, có nút lọc tròn trắng bên phải.
class RcGlassSearch extends StatelessWidget {
  final Widget child; // thường là TextField
  final VoidCallback? onFilter;
  final bool filterActive; // đang lọc: chấm đỏ trên nút lọc
  const RcGlassSearch({super.key, required this.child, this.onFilter, this.filterActive = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 62,
          color: Colors.white.withValues(alpha: 0.2),
          padding: const EdgeInsets.only(left: 18, right: 6),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(child: child),
              if (onFilter != null)
                GestureDetector(
                  onTap: onFilter,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.ink, size: 20),
                        if (filterActive)
                          const Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(radius: 3.5, backgroundColor: AppColors.error),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề mục: chữ 19 + dòng phụ 11 xám bên dưới, "Xem tất cả" bên phải.
class RcSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  const RcSection(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: pagePadding),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: kTitle),
                if (subtitle != null) Text(subtitle!, style: kSub12),
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(action!, style: kViewAll),
              ),
            ),
        ],
      ),
    );
  }
}

/// Khối trắng bo 22 trên nền xám.
class RcCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final Color color;
  const RcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Nút tròn 42: trắng có bóng nhẹ (trên ảnh), hoặc kính mờ (trên đầu trang tối).
class RcCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool glass;
  final double size;
  final Color? color;
  const RcCircleButton({super.key, required this.icon, this.onTap, this.glass = false, this.size = 42, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: glass ? Colors.white.withValues(alpha: 0.18) : Colors.white,
          boxShadow: glass ? null : const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: size * 0.45, color: color ?? (glass ? Colors.white : AppColors.ink)),
      ),
    );
  }
}

/// Vòng tròn icon nền hồng xám (mẫu: các dòng của màn Settings).
class RcIconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  final Color background;
  const RcIconCircle(
    this.icon, {
    super.key,
    this.size = 38,
    this.color = AppColors.ink,
    this.background = AppColors.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

/// Nhóm dòng menu trong một khối trắng, có nhãn nhỏ xám ở trên (mẫu: "Preferences", "Account").
class RcMenuGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;
  const RcMenuGroup({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return RcCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
              child: Text(label!, style: kText(14, FontWeight.w300, color: AppColors.muted)),
            ),
          ...children,
        ],
      ),
    );
  }
}

/// Một dòng menu: vòng tròn icon · tên · (dòng phụ) · phần đuôi (mặc định mũi tên).
class RcMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  const RcMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            RcIconCircle(
              icon,
              size: 40,
              color: color,
              background: danger ? AppColors.error.withValues(alpha: 0.08) : AppColors.tint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kText(16, FontWeight.w400, color: color)),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: kSub12),
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

/// Viên thuốc chọn lọc (danh mục): vòng tròn logo/icon bên trái + tên. Đang chọn nền đen chữ trắng.
class RcChip extends StatelessWidget {
  final String label;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  const RcChip({super.key, required this.label, this.leading, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        padding: EdgeInsets.only(left: leading == null ? 16 : 8, right: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              // Logo danh mục trong khung tròn, không có nền phía sau
              ClipOval(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: IconTheme(
                      data: IconThemeData(size: 22, color: selected ? Colors.white : AppColors.ink),
                      child: leading!,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: kText(
                13,
                selected ? FontWeight.w400 : FontWeight.w300,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung ảnh vuông (mặc định nền trắng như thẻ của mẫu), ảnh hiện trọn (không cắt) – áp dụng cho mọi ảnh đồ cho thuê.
class RcSquareImage extends StatelessWidget {
  final String? url;
  final String categoryName;
  final double radius;
  final double inset;
  final Color background;
  const RcSquareImage({
    super.key,
    this.url,
    required this.categoryName,
    this.radius = 16,
    this.inset = 4,
    this.background = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: background,
          child: LayoutBuilder(
            builder: (context, c) {
              final fallback = ItemThumb(categoryName: categoryName, size: c.maxWidth, height: c.maxHeight, radius: 0);
              if (url == null) return fallback;
              return Padding(
                padding: EdgeInsets.all(inset),
                child: Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Thanh điều hướng nổi kính mờ của mẫu: các nút tròn, nút đang chọn màu đen.
class RcNavPill extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final Set<int> dots; // nút có chấm đỏ (có thông báo/tin chưa đọc)
  const RcNavPill({super.key, required this.index, required this.onTap, required this.icons, this.dots = const {}});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: (bottom > 0 ? bottom : 12) + 6),
      child: Center(
        heightFactor: 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: const Color(0xFFEBECEE).withValues(alpha: 0.72),
                padding: const EdgeInsets.all(5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < icons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => onTap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == index ? AppColors.primary : Colors.white.withValues(alpha: 0.8),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(icons[i], size: 24, color: i == index ? Colors.white : const Color(0xFF222326)),
                              if (dots.contains(i))
                                const Positioned(
                                  top: 15,
                                  right: 15,
                                  child: CircleAvatar(radius: 3.5, backgroundColor: AppColors.error),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hộp "Hỗ trợ": số điện thoại / email hỗ trợ do quản trị cài đặt, chạm để chép.
void showSupportSheet(BuildContext context) {
  final contacts = <(IconData, String)>[
    if (AppConfig.supportPhone != null) (Icons.call_outlined, AppConfig.supportPhone!),
    if (AppConfig.supportEmail != null) (Icons.mail_outline_rounded, AppConfig.supportEmail!),
  ];
  showAppSheet<void>(
    context,
    title: tr('Hỗ trợ'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(pagePadding + 4, 0, pagePadding + 4, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Cần giúp đỡ? Liên hệ đội ngũ hỗ trợ, chạm để chép thông tin.'),
            style: kText(14, FontWeight.w300, lh: 21, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (contacts.isEmpty)
            Text(tr('Chưa có thông tin liên hệ.'), style: kText(14, FontWeight.w300))
          else
            for (final c in contacts)
              RcMenuItem(
                icon: c.$1,
                title: c.$2,
                trailing: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: c.$2));
                  Navigator.pop(ctx);
                  showSnack(context, tr('Đã chép {0}', [c.$2]));
                },
              ),
        ],
      ),
    ),
  );
}

/// Khung màn đăng nhập / đăng ký: ảnh đầu trang (tên app giữa, cờ ngôn ngữ phải, lời chào lớn),
/// khối trắng bo 28 đè lên mép ảnh chứa form, giống tờ "Pickup & Return" của mẫu.
class RcAuthLayout extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? leading;
  const RcAuthLayout({super.key, required this.title, this.subtitle, required this.child, this.trailing, this.leading});

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        children: [
          RcHero(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child:
                            leading ??
                            (canPop
                                ? IconButton(
                                    icon: const Icon(Icons.arrow_back_rounded, size: 26, color: Colors.white),
                                    onPressed: () => Navigator.maybePop(context),
                                  )
                                : null),
                      ),
                      Expanded(
                        child: Text(
                          appName,
                          textAlign: TextAlign.center,
                          style: kText(22, FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      SizedBox(width: 56, child: Center(child: trailing)),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(title, style: kText(28, FontWeight.w400, lh: 34, color: Colors.white)),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Text(
                      subtitle!,
                      style: kText(13, FontWeight.w300, lh: 19, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -46),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hộp "Giới thiệu về RentMate" (menu ☰ và Tài khoản).
void showAboutSheet(BuildContext context) {
  showAppSheet<void>(
    context,
    title: tr('Giới thiệu về {0}', [appName]),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(pagePadding + 4, 0, pagePadding + 4, 28),
      child: Text(
        tr(
          '{0} là nơi cho thuê và thuê đồ giữa mọi người: đăng món đồ bạn ít dùng để kiếm thêm, hoặc thuê đúng thứ bạn cần trong vài ngày thay vì phải mua. Tiền thuê và tiền cọc được giữ an toàn trong ví, có biên bản giao nhận bằng ảnh cho cả hai bên.',
          [appName],
        ),
        style: kText(14, FontWeight.w300, lh: 22),
      ),
    ),
  );
}

/// Ô ngôn ngữ ở cuối dòng "Ngôn ngữ" (như ô "US$ 🇺🇸" của mẫu): khung viền bo nhẹ, mã ngôn ngữ + cờ tròn.
class LanguageBadge extends StatelessWidget {
  final String code;
  const LanguageBadge({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code.toUpperCase(), style: kText(15, FontWeight.w400)),
          const SizedBox(width: 8),
          RcFlag(code, size: 26),
        ],
      ),
    );
  }
}

/// Nhãn xám bo tròn ở góc thẻ, như "10% OFF" của mẫu Deals
class RcTag extends StatelessWidget {
  final String text;
  final bool dark;
  const RcTag(this.text, {super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.primary : const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: kText(12, FontWeight.w400, color: dark ? Colors.white : AppColors.ink)),
    );
  }
}

/// Khối ưu đãi trong chi tiết đồ: "Giảm 10% khi thuê từ 7 ngày"
class DealBanner extends StatelessWidget {
  final Item item;
  const DealBanner({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(color: const Color(0xFFF1F2F4), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          RcTag(tr('-{0}%', [item.discountPercent]), dark: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('Giảm {0}% tiền thuê khi thuê từ {1} ngày', [item.discountPercent, item.discountMinDays]),
              style: kText(13, FontWeight.w400, lh: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thẻ "Deals" của mẫu: nhãn giảm giá góc trái, ảnh giữa, "Giảm đến X%" giữa, mô tả xám, nút đen "Xem chi tiết"
class DealCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  const DealCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 130,
                      child: RcSquareImage(url: item.imageUrl, categoryName: item.categoryName, radius: 12, inset: 0),
                    ),
                  ),
                  Positioned(left: 0, top: 0, child: RcTag(tr('Giảm {0}%', [item.discountPercent]))),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kText(18, FontWeight.w400, lh: 24),
              ),
              const SizedBox(height: 4),
              Text(
                tr('Giảm {0}% tiền thuê khi thuê từ {1} ngày. Giá gốc {2}/ngày.', [
                  item.discountPercent,
                  item.discountMinDays,
                  formatVnd(item.pricePerDay),
                ]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: kText(12, FontWeight.w300, lh: 17, color: AppColors.muted),
              ),
              const Spacer(),
              FilledButton(onPressed: onTap, child: Text(tr('Xem chi tiết'))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trái tim lưu yêu thích: viền khi chưa lưu, tô đen khi đã lưu. Khách chưa đăng nhập thì nhắc đăng nhập.
/// [circle]: đặt trong vòng tròn trắng (đầu ảnh chi tiết đồ), không thì chỉ có icon (góc thẻ).
class FavoriteHeart extends StatelessWidget {
  final int itemId;
  final bool circle;
  const FavoriteHeart({super.key, required this.itemId, this.circle = false});

  Future<void> _toggle(BuildContext context) async {
    if (await AuthService().getToken() == null) {
      if (context.mounted) requireLogin(context, tr('lưu món đồ yêu thích'));
      return;
    }
    try {
      await FavoriteCenter.toggle(itemId);
    } catch (e) {
      if (context.mounted) showSnack(context, errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: FavoriteCenter.ids,
      builder: (context, ids, _) {
        final saved = ids.contains(itemId);
        final icon = saved ? Icons.favorite_rounded : Icons.favorite_border_rounded;
        if (circle) {
          return RcCircleButton(icon: icon, onTap: () => _toggle(context));
        }
        return GestureDetector(
          onTap: () => _toggle(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(icon, key: ValueKey(saved), size: 22, color: AppColors.ink),
            ),
          ),
        );
      },
    );
  }
}
