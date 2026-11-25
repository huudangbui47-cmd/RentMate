import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/notification_service.dart';
import '../services/view_history.dart';
import '../theme.dart';
import '../widgets/kit.dart';
import '../widgets/ui.dart';
import '../services/account_service.dart';
import 'select_date_screen.dart';
import 'guest_screen.dart';
import 'main_shell.dart';
import 'rental_screen.dart';
import 'user_profile_screen.dart';
import '../l10n/l10n.dart';

class ItemDetailScreen extends StatefulWidget {
  final int itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Future<(Item, String?)> _future = _load();
  bool _guest = false;
  DateTimeRange? _range; // ngày khách chọn ở mục "Ngày thuê"
  bool _moreDescription = false;
  DateTime? _ownerJoined;

  Future<(Item, String?)> _load() async {
    final item = await ItemService().getItem(widget.itemId);
    final userId = await AuthService().getUserId();
    // Ghi lượt xem để gợi ý ở trang chủ (chỉ khi đã đăng nhập, không tính đồ của chính mình)
    if (userId != null && item.ownerId != userId) {
      await ViewHistory.record(userId, item.id, item.categoryId);
    }
    // Ngày chủ đồ tham gia (hiện trong khung chủ đồ); lỗi thì bỏ qua
    AccountService()
        .getPublicProfile(item.ownerId)
        .then((p) {
          if (mounted) {
            setState(() {
              _ownerJoined = p.createdAt;
            });
          }
        })
        .catchError((_) {});
    return (item, userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<(Item, String?)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return SafeArea(
              child: ErrorView(
                message: errorText(snap.error!),
                onRetry: () => setState(() {
                  _future = _load();
                }),
              ),
            );
          }
          final (item, userId) = snap.data!;
          _guest = userId == null;
          return _content(item, item.ownerId == userId);
        },
      ),
    );
  }

  void _soon(String what) => showSnack(context, tr('{0} sẽ có trong bản cập nhật tới.', [what]));

  Future<void> _pickDates(Item item) async {
    final picked = await SelectDateScreen.open(context, initial: _range, rentFor: item.rentFor);
    if (picked != null) {
      setState(() {
        _range = picked;
      });
    }
  }

  Future<void> _book(Item item) async {
    if (_guest) {
      requireLogin(context, tr('thuê đồ'));
      return;
    }
    final range = _range ?? await SelectDateScreen.open(context, rentFor: item.rentFor);
    if (range == null || !mounted) return;
    setState(() {
      _range = range;
    });
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RentalScreen(item: item, initialRange: range),
      ),
    );
    if (ok == true && mounted) {
      await showSuccessSheet(
        context,
        icon: Icons.receipt_long_rounded,
        title: tr('Đặt thuê thành công'),
        message: tr('Đã gửi yêu cầu thuê, chờ chủ đồ duyệt.'),
        buttonText: tr('Xem chuyến thuê'),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      NotificationCenter.instance.openTab?.call(MainShell.rentalsTab);
    }
  }

  // Bố cục theo ngôn ngữ của mẫu Rentcars: ảnh vuông lớn trên nền xám nhạt bo đáy, các khối trắng bo 22,
  // thanh dưới có tổng tiền và nút đen viên thuốc.
  Widget _content(Item item, bool mine) {
    final rented = item.status == 'Rented';
    final canRent = !mine && (item.status == 'Available' || rented);
    final loc = MaterialLocalizations.of(context);
    final basics = <(String, String)>[
      (tr('Tiền cọc'), formatVnd(item.depositAmount)),
      (tr('Tình trạng'), conditionLabels[item.condition] ?? item.condition),
      (tr('Danh mục'), tr(item.categoryName)),
      (tr('Đăng ngày'), fmtDate(item.createdAt)),
    ];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              _Gallery(
                images: item.images,
                categoryName: item.categoryName,
                onBack: () => Navigator.pop(context),
                itemId: item.id,
              ),
              // Tên · giá · khu vực · lượt thuê
              RcCard(
                margin: const EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(item.name, style: kText(20, FontWeight.w400, lh: 26))),
                        const SizedBox(width: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: formatVnd(item.pricePerDay), style: kText(20, FontWeight.w600, lh: 26)),
                              TextSpan(
                                text: tr('/ngày'),
                                style: kText(11, FontWeight.w300, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        _meta(Icons.location_on_outlined, item.province ?? tr('Toàn quốc')),
                        if (item.rentCount > 0) _meta(Icons.repeat_rounded, tr('{0} lượt thuê', [item.rentCount])),
                        if (rented) _meta(Icons.schedule_rounded, tr('Đang có người thuê')),
                      ],
                    ),
                    if (item.hasDeal) ...[const SizedBox(height: 12), DealBanner(item: item)],
                  ],
                ),
              ),
              // Thông tin thuê: lưới ô xám nhỏ
              RcCard(
                margin: const EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(tr('Thông tin'), style: kText(12, FontWeight.w300, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < basics.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: _spec(basics[i])),
                          const SizedBox(width: 8),
                          Expanded(child: i + 1 < basics.length ? _spec(basics[i + 1]) : const SizedBox()),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Ngày thuê + nơi nhận đồ: dòng kiểu menu của mẫu
              RcMenuGroup(
                children: [
                  RcMenuItem(
                    icon: Icons.calendar_today_outlined,
                    title: tr('Ngày thuê'),
                    subtitle: _range == null
                        ? tr('Chưa chọn ngày')
                        : tr('{0} đến {1}', [
                            loc.formatShortMonthDay(_range!.start),
                            loc.formatShortMonthDay(_range!.end),
                          ]),
                    trailing: canRent
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_range == null ? tr('Chọn ngày') : tr('Đổi'), style: kText(13, FontWeight.w400)),
                              const Icon(Icons.chevron_right_rounded, size: 22),
                            ],
                          )
                        : const SizedBox(),
                    onTap: canRent ? () => _pickDates(item) : null,
                  ),
                  RcMenuItem(
                    icon: Icons.location_on_outlined,
                    title: tr('Nơi nhận đồ'),
                    subtitle: item.locationText ?? tr('Hai bên tự hẹn nơi giao nhận'),
                    trailing: const SizedBox(),
                  ),
                ],
              ).withMargin(const EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0)),
              // Chủ đồ
              RcCard(
                margin: const EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                onTap: mine ? null : () => _openOwner(item),
                child: _owner(item, mine),
              ),
              // Mô tả
              RcCard(
                margin: const EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Mô tả'), style: kText(12, FontWeight.w300, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    _description(item),
                  ],
                ),
              ),
              // Chính sách tiền cọc
              RcCard(
                margin: const EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RcIconCircle(Icons.shield_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Chính sách tiền cọc'), style: kText(15, FontWeight.w400, lh: 20)),
                          const SizedBox(height: 2),
                          Text(
                            tr(
                              'Tiền cọc được giữ trong ví RentMate và hoàn lại đầy đủ khi bạn trả đồ đúng tình trạng.',
                            ),
                            style: kBody12Hint,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _bottomBar(item, mine, rented, canRent),
      ],
    );
  }

  Widget _meta(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: AppColors.muted),
      const SizedBox(width: 4),
      Text(text, style: kText(12, FontWeight.w300, color: AppColors.muted)),
    ],
  );

  Widget _spec((String, String) s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(14)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.$1, style: kText(11, FontWeight.w300, lh: 15, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(s.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: kText(14, FontWeight.w500, lh: 19)),
      ],
    ),
  );

  void _openOwner(Item item) {
    if (_guest) {
      requireLogin(context, tr('xem hồ sơ chủ đồ'));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfileScreen(userId: item.ownerId)));
  }

  // Ảnh đại diện · tên · ngày tham gia, nút chat tròn bên phải
  Widget _owner(Item item, bool mine) {
    final joined = _ownerJoined;
    return Row(
      children: [
        UserAvatar(name: item.ownerName, url: item.ownerAvatarUrl, radius: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.ownerName, style: kText(15, FontWeight.w400, lh: 20)),
              Text(
                [
                  mine ? tr('Đây là đồ của bạn') : tr('Chủ đồ'),
                  if (joined != null) tr('Tham gia {0}', ['${joined.month.toString().padLeft(2, '0')}/${joined.year}']),
                ].join(' · '),
                style: kSub12,
              ),
            ],
          ),
        ),
        if (!mine)
          GestureDetector(
            onTap: () => _soon(tr('Nhắn tin với chủ đồ')),
            child: const RcIconCircle(Icons.chat_bubble_outline_rounded, size: 40),
          ),
      ],
    );
  }

  Widget _description(Item item) {
    final text = item.description.isEmpty ? tr('(Chủ đồ chưa viết mô tả)') : item.description;
    final long = text.length > 140;
    final style = kText(13, FontWeight.w300, lh: 20, color: const Color(0xFF4A4D53));
    if (!long || _moreDescription) return Text(text, style: style);
    return GestureDetector(
      onTap: () => setState(() {
        _moreDescription = true;
      }),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${text.substring(0, 140).trimRight()}... ', style: style),
            TextSpan(text: tr('Xem thêm'), style: kText(13, FontWeight.w500, lh: 20)),
          ],
        ),
      ),
    );
  }

  // Thanh dưới trên nền xám: tổng tiền (hoặc giá + cọc) bên trái, nút đen "Đặt thuê" bên phải
  Widget _bottomBar(Item item, bool mine, bool rented, bool canRent) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final days = _range == null ? 0 : _range!.end.difference(_range!.start).inDays + 1;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, pagePadding, bottom > 14 ? bottom : 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  days > 0 ? tr('Tổng {0} ngày', [days]) : tr('Cọc {0}', [formatVnd(item.depositAmount)]),
                  style: kText(12, FontWeight.w300, color: AppColors.muted),
                ),
                Text(
                  formatVnd(days > 0 ? item.rentFor(days) : item.pricePerDay) + (days > 0 ? '' : tr('/ngày')),
                  style: kText(18, FontWeight.w600, lh: 24),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          KitButton(
            mine
                ? tr('Đồ của bạn')
                : rented
                ? tr('Đặt ngày khác')
                : tr('Đặt thuê'),
            onPressed: canRent ? () => _book(item) : null,
          ),
        ],
      ),
    );
  }
}

extension on Widget {
  Widget withMargin(EdgeInsets margin) => Padding(padding: margin, child: this);
}

/// Ảnh đầy chiều ngang trên khối trắng bo đáy (ảnh hiện trọn, không cắt), vuốt ngang để xem ảnh khác.
/// Nút quay lại và tim tròn trắng nằm trên ảnh, chấm vị trí ở đáy: chấm đang xem là viên thuốc đen.
class _Gallery extends StatefulWidget {
  final List<ItemImage> images;
  final String categoryName;
  final VoidCallback onBack;
  final int itemId;
  const _Gallery({required this.images, required this.categoryName, required this.onBack, required this.itemId});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final top = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: ColoredBox(
        color: Colors.white,
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: top + 56, bottom: 30),
              child: AspectRatio(
                aspectRatio: 1.15,
                child: images.isEmpty
                    ? LayoutBuilder(
                        builder: (_, c) => ItemThumb(
                          categoryName: widget.categoryName,
                          size: c.maxWidth,
                          height: c.maxHeight,
                          radius: 0,
                        ),
                      )
                    : PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() {
                          _page = i;
                        }),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _FullScreenGallery(images: images, initialPage: i),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Image.network(
                              images[i].url,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, p) =>
                                  p == null ? child : const Center(child: CircularProgressIndicator()),
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.broken_image_outlined, size: 48, color: AppColors.muted),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            Positioned(
              top: top + 6,
              left: pagePadding,
              right: pagePadding,
              child: Row(
                children: [
                  RcCircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: widget.onBack),
                  const Spacer(),
                  FavoriteHeart(itemId: widget.itemId, circle: true),
                ],
              ),
            ),
            if (images.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < images.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: i == _page ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.ink : const Color(0xFFC9CBD0),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenGallery extends StatefulWidget {
  final List<ItemImage> images;
  final int initialPage;
  const _FullScreenGallery({required this.images, required this.initialPage});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_page + 1}/${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() {
          _page = i;
        }),
        // Chụm 2 ngón để phóng to
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(child: Image.network(widget.images[i].url, fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
