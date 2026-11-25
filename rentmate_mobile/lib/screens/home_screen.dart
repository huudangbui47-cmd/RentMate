import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/notification_service.dart';
import '../services/view_history.dart';
import '../services/banner_service.dart';
import '../widgets/language_picker.dart';
import '../theme.dart';
import '../widgets/kit.dart';
import '../widgets/ui.dart';
import 'main_shell.dart';
import 'item_detail_screen.dart';
import 'guest_screen.dart';
import 'favorites_screen.dart';
import 'item_form_screen.dart';
import '../l10n/l10n.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = ItemService();
  List<Item> _items = [];
  List<Category> _categories = [];
  List<String> _provinces = [];
  String? _province; // tỉnh/thành đang lọc, null = toàn quốc (nhớ cho lần mở app sau)
  static const _provinceKey = 'home_province';
  int? _parentId; // danh mục cha đang chọn, null = tất cả
  int? _childId; // danh mục con đang chọn trong danh mục cha
  String _search = '';
  String? _sort; // null = mặc định: khách "Được thuê nhiều nhất", đã đăng nhập "Dành cho bạn"
  Map<int, double> _categoryScore = {}; // điểm sở thích theo danh mục (từ lượt xem và đơn đã thuê)
  String _name = '';
  String? _userId;
  bool _loading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Banner dùng chung cho mọi đầu trang; lỗi thì vẫn hiện nền tối mặc định
      if (BannerCenter.banners.value.isEmpty) BannerCenter.load();
      final results = await Future.wait([_service.getItems(), _service.getCategories(), _service.getProvinces()]);
      final prefs = await SharedPreferences.getInstance();
      final auth = AuthService();
      _name = await auth.getFullName() ?? '';
      _userId = await auth.getUserId();
      final items = results[0] as List<Item>;
      final categories = results[1] as List<Category>;
      final provinces = results[2] as List<String>;
      final savedProvince = prefs.getString(_provinceKey);
      final scores = _userId == null ? <int, double>{} : await _buildCategoryScore(_userId!, items, categories);
      if (!mounted) return;
      setState(() {
        _items = items;
        _categories = categories;
        _categoryScore = scores;
        _provinces = provinces;
        _province = provinces.contains(savedProvince) ? savedProvince : null;
        // Danh mục đang chọn vừa bị ẩn thì quay về "Tất cả"
        if (!_categories.any((c) => c.id == _parentId)) _parentId = null;
        if (!_categories.any((c) => c.id == _childId)) _childId = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _effectiveSort => _sort ?? (_userId == null ? 'popular' : 'forYou');

  /// Điểm giảm một nửa sau mỗi 7 ngày.
  static double _decay(DateTime at) => pow(0.5, DateTime.now().difference(at).inHours / (24 * 7)).toDouble();

  /// Điểm sở thích theo danh mục: xem chi tiết = 2, đã thuê = 5, giảm dần theo thời gian.
  /// Danh mục cha cũng được cộng một nửa để gợi ý cả các danh mục con "anh em".
  Future<Map<int, double>> _buildCategoryScore(String userId, List<Item> items, List<Category> categories) async {
    final parentOf = {for (final c in categories) c.id: c.parentId};
    final scores = <int, double>{};
    void add(int categoryId, double points) {
      scores[categoryId] = (scores[categoryId] ?? 0) + points;
      final parent = parentOf[categoryId];
      if (parent != null) scores[parent] = (scores[parent] ?? 0) + points / 2;
    }

    for (final v in await ViewHistory.load(userId)) {
      add(v.categoryId, 2 * _decay(v.viewedAt));
    }
    try {
      final categoryOfItem = {for (final i in items) i.id: i.categoryId};
      for (final r in await RentalService().getMyRentals()) {
        final categoryId = categoryOfItem[r.itemId];
        if (r.renterId == userId && categoryId != null) add(categoryId, 5 * _decay(r.requestedAt));
      }
    } catch (_) {
      // Không tải được đơn thuê thì vẫn gợi ý theo lượt xem
    }
    return scores;
  }

  double _itemScore(Item item) {
    final category = _categories.where((c) => c.id == item.categoryId);
    final parent = category.isEmpty ? null : category.first.parentId;
    return (_categoryScore[item.categoryId] ?? 0) +
        (parent == null ? 0 : (_categoryScore[parent] ?? 0) / 2) +
        0.1 * item.rentCount;
  }

  List<Category> get _parents => _categories.where((c) => c.parentId == null).toList();

  List<Category> get _children => _parentId == null ? [] : _categories.where((c) => c.parentId == _parentId).toList();

  bool _matchesCategory(Item item) {
    if (_childId != null) return item.categoryId == _childId;
    if (_parentId == null) return true;
    if (item.categoryId == _parentId) return true;
    // Chọn danh mục cha thì hiện cả đồ thuộc các danh mục con của nó
    return _categories.any((c) => c.id == item.categoryId && c.parentId == _parentId);
  }

  Future<void> _pickProvince() async {
    // Đếm số đồ mỗi tỉnh để khách biết chỗ nào có đồ
    final counts = <String, int>{};
    for (final i in _items) {
      if (i.province != null) counts[i.province!] = (counts[i.province!] ?? 0) + 1;
    }
    Widget row(String label, int count, bool selected, String value) => InkWell(
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: pagePadding, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
            Text('$count', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(width: 14),
            TickBox(selected: selected),
          ],
        ),
      ),
    );
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Center(child: Text(tr('Khu vực nhận đồ'), style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 12),
            row(tr('Toàn quốc'), _items.length, _province == null, ''),
            for (final p in _provinces) row(p, counts[p] ?? 0, _province == p, p),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final value = picked.isEmpty ? null : picked;
    setState(() {
      _province = value;
    });
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_provinceKey);
    } else {
      await prefs.setString(_provinceKey, value);
    }
  }

  List<Item> get _visibleItems {
    final keyword = _search.trim().toLowerCase();
    final list = _items
        .where((i) => _province == null || i.province == _province)
        .where(_matchesCategory)
        .where(
          (i) =>
              keyword.isEmpty ||
              i.name.toLowerCase().contains(keyword) ||
              i.description.toLowerCase().contains(keyword),
        )
        .toList();
    int newestFirst(Item a, Item b) => b.createdAt.compareTo(a.createdAt);
    switch (_effectiveSort) {
      case 'forYou':
        final score = {for (final i in list) i.id: _itemScore(i)};
        list.sort((a, b) {
          final c = score[b.id]!.compareTo(score[a.id]!);
          return c != 0 ? c : newestFirst(a, b);
        });
      case 'popular':
        list.sort((a, b) {
          final c = b.rentCount.compareTo(a.rentCount);
          return c != 0 ? c : newestFirst(a, b);
        });
      case 'deals':
        // Đồ có ưu đãi lên đầu, giảm nhiều trước
        list.sort((a, b) {
          final c = b.discountPercent.compareTo(a.discountPercent);
          return c != 0 ? c : newestFirst(a, b);
        });
      case 'priceAsc':
        list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      case 'priceDesc':
        list.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  void _openItem(Item item) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id))).then((_) => _load());

  // Chiều cao phần đầu trang (không tính thanh trạng thái): hàng ☰ 44 + 24 + lời chào 50 + 20 + ô tìm 62 + 22
  static const double _heroBody = 222;

  // Bố cục theo màn "Home" của mẫu Rentcars: đầu trang ảnh đứng yên, nội dung cuộn chui bên dưới góc bo;
  // thân nền xám: danh mục, "Mới đăng" (thẻ lớn như "Top trends"), "Được thuê nhiều" (thẻ nhỏ như
  // "Popular vehicles") và lưới khám phá.
  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final searching = _search.trim().isNotEmpty;
    final heroHeight = MediaQuery.of(context).padding.top + _heroBody;
    // Nút Back khi menu ☰ đang mở: đóng menu thay vì thoát app (Android 14+ cần báo trước là app tự xử lý Back)
    return PopScope(
      canPop: !_drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _scaffoldKey.currentState?.closeDrawer();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _drawer(),
        onDrawerChanged: (open) {
          navPillHidden.value = open;
          setState(() {
            _drawerOpen = open;
          });
        },
        body: Stack(
          children: [
            Positioned.fill(
              child: RefreshIndicator(
                color: AppColors.primary,
                edgeOffset: heroHeight,
                onRefresh: () async {
                  await Future.wait([_load(), BannerCenter.load()]);
                },
                child: ListView(
                  padding: EdgeInsets.only(top: heroHeight + 6, bottom: navPillSpace(context)),
                  children: [
                    if (_loading && _items.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 80), child: LoadingView())
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: ErrorView(message: _error!, onRetry: _load),
                      )
                    else ...[
                      if (!searching) ...[
                        if (_categories.isNotEmpty) ...[const SizedBox(height: 10), _categoryChips()],
                        if (_children.isNotEmpty) ...[const SizedBox(height: 8), _childChips()],
                        _dealRow(
                          [...items.where((i) => i.hasDeal)]
                            ..sort((a, b) => b.discountPercent.compareTo(a.discountPercent)),
                        ),
                        _bigRow(
                          tr('Mới đăng'),
                          tr('Hàng mới lên kệ, thuê ngay kẻo lỡ'),
                          [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
                          () => setState(() {
                            _sort = 'newest';
                          }),
                        ),
                        _smallRow(
                          tr('Được thuê nhiều'),
                          tr('Những món được cộng đồng yêu thích nhất'),
                          [...items.where((i) => i.rentCount > 0)]..sort((a, b) => b.rentCount.compareTo(a.rentCount)),
                          () => setState(() {
                            _sort = 'popular';
                          }),
                        ),
                      ],
                      if (!searching) _postCta(),
                      const SizedBox(height: 22),
                      _grid(items, searching),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(top: 0, left: 0, right: 0, height: heroHeight, child: _hero()),
          ],
        ),
      ),
    );
  }

  // Đầu trang: ☰ · tên app ở giữa · cờ tròn (đổi Việt/Anh); lời chào; ô tìm kiếm kính mờ có nút lọc
  Widget _hero() {
    final name = _name.trim();
    return RcHero(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  behavior: HitTestBehavior.opaque,
                  child: const SizedBox(
                    width: 44,
                    height: 44,
                    child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.menu_rounded, size: 28)),
                  ),
                ),
                Expanded(
                  child: Text(
                    appName,
                    textAlign: TextAlign.center,
                    style: kText(22, FontWeight.w600, tracking: -0.01, color: Colors.white),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FlagToggleButton(rebuild: () => MainShell(guest: _userId == null)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            name.isEmpty ? tr('Chào bạn') : tr('Chào, {0}', [name]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kText(27, FontWeight.w400, lh: 32, color: Colors.white),
          ),
          Text(
            tr('Hôm nay bạn cần thuê gì?'),
            style: kText(12, FontWeight.w300, lh: 18, color: Colors.white.withValues(alpha: 0.85)),
          ),
          const Spacer(),
          RcGlassSearch(
            onFilter: _openFilter,
            filterActive: _province != null || _sort != null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 22,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    cursorColor: Colors.white,
                    style: kText(15, FontWeight.w400, lh: 20, color: Colors.white),
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: tr('Tìm đồ cần thuê?'),
                      hintStyle: kText(15, FontWeight.w400, lh: 20, color: Colors.white),
                    ),
                  ),
                ),
                // Dòng phụ như "Anywhere • Anytime" của mẫu: khu vực đang lọc · kiểu sắp xếp
                Text(
                  '${_province ?? tr('Toàn quốc')}  •  ${_sortTitles[_effectiveSort]}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kText(12, FontWeight.w300, lh: 16, color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> get _sortTitles => {
    'forYou': tr('Dành cho bạn'),
    'popular': tr('Được thuê nhiều nhất'),
    'newest': tr('Mới đăng'),
    'deals': tr('Ưu đãi'),
    'priceAsc': tr('Giá thấp → cao'),
    'priceDesc': tr('Giá cao → thấp'),
  };

  // Nút lọc trong ô tìm kiếm: chọn khu vực nhận đồ và cách sắp xếp
  Future<void> _openFilter() async {
    final options = {
      if (_userId != null) 'forYou': _sortTitles['forYou']!,
      for (final k in ['popular', 'newest', 'priceAsc', 'priceDesc']) k: _sortTitles[k]!,
    };
    final picked = await showAppSheet<String>(
      context,
      title: tr('Bộ lọc'),
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(pagePadding + 4, 0, pagePadding + 4, 20),
        children: [
          Text(tr('Khu vực nhận đồ'), style: kText(14, FontWeight.w300, color: AppColors.muted)),
          const SizedBox(height: 8),
          // Ô xám dạng viên thuốc như "Search for destinations" của màn Pickup & Return
          Material(
            color: AppColors.field,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: _provinces.isEmpty ? null : () => Navigator.pop(ctx, '@province'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 21),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_province ?? tr('Toàn quốc'), style: kText(15, FontWeight.w300))),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(tr('Sắp xếp'), style: kText(14, FontWeight.w300, color: AppColors.muted)),
          const SizedBox(height: 4),
          for (final e in options.entries)
            InkWell(
              onTap: () => Navigator.pop(ctx, e.key),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(e.value, style: kText(15, FontWeight.w300))),
                    TickBox(selected: _effectiveSort == e.key),
                  ],
                ),
              ),
            ),
          if (_province != null || _sort != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => Navigator.pop(ctx, '@reset'), child: Text(tr('Bỏ lọc'))),
          ],
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (picked == '@province') {
      await _pickProvince();
    } else if (picked == '@reset') {
      setState(() {
        _sort = null;
        _province = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_provinceKey);
    } else {
      setState(() {
        _sort = picked;
      });
    }
  }

  // Menu ☰ gọn: Danh mục (tiêu đề) · Trang chủ · Sản phẩm (mở ra danh mục) · Giới thiệu · Đăng nhập/Đăng ký · Hỗ trợ
  Widget _drawer() {
    final guest = _userId == null;
    void close() => Navigator.of(context).pop();
    void pickCategory(int? parentId, int? childId) {
      close();
      setState(() {
        _parentId = parentId;
        _childId = childId;
      });
    }

    final titleStyle = kText(16, FontWeight.w400);
    final subStyle = kText(15, FontWeight.w300);
    Widget tile(IconData icon, String title, VoidCallback onTap) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      minLeadingWidth: 0,
      horizontalTitleGap: 14,
      leading: Icon(icon, size: 22, color: AppColors.ink),
      title: Text(title, style: titleStyle),
      onTap: onTap,
    );
    Widget expansion({
      required Widget leading,
      required String title,
      required List<Widget> children,
      bool open = false,
    }) => Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        listTileTheme: const ListTileThemeData(horizontalTitleGap: 14, minLeadingWidth: 0),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 22),
        childrenPadding: const EdgeInsets.only(left: 36),
        minTileHeight: 52,
        leading: leading,
        title: Text(title, style: titleStyle),
        iconColor: AppColors.ink,
        collapsedIconColor: AppColors.muted,
        initiallyExpanded: open,
        children: children,
      ),
    );
    Widget sub(String title, bool selected, VoidCallback onTap) => ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      title: Text(title, style: selected ? kText(15, FontWeight.w500) : subStyle),
      trailing: selected ? const Icon(Icons.check_rounded, size: 18) : null,
      onTap: onTap,
    );

    return Drawer(
      backgroundColor: Colors.white,
      width: 300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(26))),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 10, 10),
              child: Row(
                children: [
                  Expanded(child: Text(tr('Danh mục'), style: kText(24, FontWeight.w500))),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: close),
                ],
              ),
            ),
            tile(Icons.home_outlined, tr('Trang chủ'), () => pickCategory(null, null)),
            expansion(
              leading: const Icon(Icons.grid_view_rounded, size: 22, color: AppColors.ink),
              title: tr('Sản phẩm'),
              open: _parentId != null,
              children: [
                sub(tr('Tất cả sản phẩm'), _parentId == null, () => pickCategory(null, null)),
                for (final p in _parents)
                  if (_categories.any((c) => c.parentId == p.id))
                    expansion(
                      leading: Icon(ItemThumb.iconFor(p.name), size: 20, color: AppColors.ink),
                      title: tr(p.name),
                      open: _parentId == p.id,
                      children: [
                        sub(tr('Tất cả'), _parentId == p.id && _childId == null, () => pickCategory(p.id, null)),
                        for (final c in _categories.where((c) => c.parentId == p.id))
                          sub(tr(c.name), _childId == c.id, () => pickCategory(p.id, c.id)),
                      ],
                    )
                  else
                    sub(tr(p.name), _parentId == p.id, () => pickCategory(p.id, null)),
              ],
            ),
            tile(Icons.local_offer_outlined, tr('Ưu đãi'), () {
              close();
              setState(() {
                _sort = 'deals';
              });
            }),
            tile(Icons.favorite_border_rounded, tr('Yêu thích'), () {
              close();
              _openFavorites();
            }),
            tile(Icons.add_circle_outline_rounded, tr('Đăng đồ cho thuê'), () {
              close();
              _postItem();
            }),
            tile(Icons.info_outline_rounded, tr('Giới thiệu về {0}', [appName]), () {
              close();
              showAboutSheet(context);
            }),
            if (guest)
              tile(Icons.login_rounded, tr('Đăng nhập / Đăng ký'), () => goToLogin(context))
            else
              tile(Icons.person_outline_rounded, tr('Tài khoản của tôi'), () {
                close();
                NotificationCenter.instance.openTab?.call(MainShell.accountTab);
              }),
            tile(Icons.support_agent_rounded, tr('Hỗ trợ'), () {
              close();
              showSupportSheet(context);
            }),
          ],
        ),
      ),
    );
  }

  void _openFavorites() {
    if (_userId == null) {
      requireLogin(context, tr('xem danh sách yêu thích'));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesScreen()));
  }

  Future<void> _postItem() async {
    if (_userId == null) {
      requireLogin(context, tr('đăng đồ cho thuê'));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ItemFormScreen()));
    if (mounted) await _load();
  }

  // Khối đen mời cho thuê (như thẻ quảng bá của mẫu): chữ trắng, nút trắng "Đăng đồ"
  Widget _postCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(pagePadding, 24, pagePadding, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(28)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Có đồ ít dùng?'), style: kText(20, FontWeight.w500, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    tr('Đăng lên {0} để kiếm thêm thu nhập, tiền về ví sau mỗi đơn.', [appName]),
                    style: kText(13, FontWeight.w300, lh: 19, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            KitButton(tr('Đăng đồ'), small: true, light: true, onPressed: _postItem),
          ],
        ),
      ),
    );
  }

  // Logo danh mục: icon quản trị chọn, đặt thẳng trong khung tròn (không nền)
  Widget _categoryLogo(Category c) => Icon(ItemThumb.iconFor(c.name));

  Widget _categoryChips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: pagePadding),
        children: [
          RcChip(
            label: tr('Tất cả'),
            leading: const Icon(Icons.grid_view_rounded),
            selected: _parentId == null,
            onTap: () => setState(() {
              _parentId = null;
              _childId = null;
            }),
          ),
          for (final c in _parents) ...[
            const SizedBox(width: 8),
            RcChip(
              label: tr(c.name),
              leading: _categoryLogo(c),
              selected: _parentId == c.id,
              onTap: () => setState(() {
                _parentId = _parentId == c.id ? null : c.id;
                _childId = null;
              }),
            ),
          ],
        ],
      ),
    );
  }

  // Danh mục con của danh mục đang chọn: viên thuốc chỉ có chữ
  Widget _childChips() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: pagePadding),
        children: [
          RcChip(
            label: tr('Tất cả'),
            selected: _childId == null,
            onTap: () => setState(() {
              _childId = null;
            }),
          ),
          for (final c in _children) ...[
            const SizedBox(width: 8),
            RcChip(
              label: tr(c.name),
              selected: _childId == c.id,
              onTap: () => setState(() {
                _childId = c.id;
              }),
            ),
          ],
        ],
      ),
    );
  }

  // "Deals" của mẫu: đồ có ưu đãi thuê dài ngày, thẻ có nhãn giảm giá và nút đen "Xem chi tiết"
  Widget _dealRow(List<Item> deals) {
    final list = deals.take(8).toList();
    if (list.isEmpty) return const SizedBox();
    final best = list.first.discountPercent;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          RcSection(
            tr('Ưu đãi'),
            subtitle: tr('Thuê càng lâu càng hời, giảm đến {0}%', [best]),
            action: tr('Xem tất cả'),
            onAction: () => setState(() {
              _sort = 'deals';
            }),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 352,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: pagePadding),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(
                width: list.length == 1 ? MediaQuery.of(context).size.width - pagePadding * 2 : 290,
                child: DealCard(item: list[i], onTap: () => _openItem(list[i])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Top trends" của mẫu: thẻ lớn cuộn ngang
  Widget _bigRow(String title, String subtitle, List<Item> sorted, VoidCallback onAll) {
    final list = sorted.take(8).toList();
    if (list.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        children: [
          RcSection(title, subtitle: subtitle, action: tr('Xem tất cả'), onAction: onAll),
          const SizedBox(height: 14),
          SizedBox(
            height: 352,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: pagePadding),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (_, i) => SizedBox(width: 262, child: _bigCard(list[i])),
            ),
          ),
        ],
      ),
    );
  }

  // "Popular vehicles" của mẫu: thẻ nhỏ cuộn ngang
  Widget _smallRow(String title, String subtitle, List<Item> sorted, VoidCallback onAll) {
    final list = sorted.take(10).toList();
    if (list.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        children: [
          RcSection(title, subtitle: subtitle, action: tr('Xem tất cả'), onAction: onAll),
          const SizedBox(height: 14),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: pagePadding),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(width: 160, child: _smallCard(list[i])),
            ),
          ),
        ],
      ),
    );
  }

  // Danh sách chính: lưới 2 cột thẻ nhỏ
  Widget _grid(List<Item> list, bool searching) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RcSection(
          searching ? tr('Kết quả tìm kiếm') : tr('Khám phá thêm'),
          subtitle: searching
              ? tr('{0} kết quả', [list.length])
              : '${_sortTitles[_effectiveSort]} · ${tr('{0} món', [list.length])}',
          action: tr('Bộ lọc'),
          onAction: _openFilter,
        ),
        const SizedBox(height: 14),
        if (list.isEmpty)
          EmptyView(
            icon: Icons.search_off_rounded,
            title: tr('Không tìm thấy đồ phù hợp'),
            subtitle: tr('Thử từ khóa khác hoặc chọn khu vực, danh mục khác.'),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: pagePadding),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _smallCard(list[i])),
                        const SizedBox(width: 12),
                        Expanded(child: i + 1 < list.length ? _smallCard(list[i + 1]) : const SizedBox()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _heart(Item item) => FavoriteHeart(itemId: item.id);

  Widget _rentedTag() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFFF1F2F4), borderRadius: BorderRadius.circular(14)),
    child: Text(tr('Đang có người thuê'), style: kText(11, FontWeight.w400)),
  );

  // Thẻ lớn: khối trắng bo 28, ảnh vuông hiện trọn món đồ ngay trên nền trắng,
  // tên (trái) · giá đậm (phải), dòng khu vực · "/ngày", dòng lượt thuê · ảnh chủ đồ
  Widget _bigCard(Item item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openItem(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RcSquareImage(url: item.imageUrl, categoryName: item.categoryName, radius: 12, inset: 0),
                  Positioned(top: 0, right: 0, child: _heart(item)),
                  if (item.status == 'Rented') Positioned(left: 0, top: 0, child: _rentedTag()),
                  if (item.hasDeal)
                    Positioned(left: 0, bottom: 0, child: RcTag(tr('-{0}%', [item.discountPercent]), dark: true)),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kText(18, FontWeight.w400, lh: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatVnd(item.pricePerDay), style: kText(18, FontWeight.w600, lh: 24)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.province ?? tr('Toàn quốc'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kText(12, FontWeight.w300, color: AppColors.muted),
                    ),
                  ),
                  Text(tr('/ngày'), style: kText(12, FontWeight.w300, color: AppColors.muted)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.star_outline_rounded, size: 16, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.rentCount > 0 ? tr('{0} lượt thuê', [item.rentCount]) : tr('Chưa có lượt thuê'),
                      style: kText(12, FontWeight.w300, color: AppColors.muted),
                    ),
                  ),
                  UserAvatar(name: item.ownerName, url: item.ownerAvatarUrl, radius: 11),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Thẻ nhỏ: khối trắng bo 24, ảnh vuông, tên, giá đậm + "/ngày"
  Widget _smallCard(Item item) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openItem(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RcSquareImage(url: item.imageUrl, categoryName: item.categoryName, radius: 10, inset: 0),
                  Positioned(top: -2, right: -2, child: _heart(item)),
                  if (item.hasDeal)
                    Positioned(left: 0, bottom: 0, child: RcTag(tr('-{0}%', [item.discountPercent]), dark: true)),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: kText(15, FontWeight.w400, lh: 20)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: formatVnd(item.pricePerDay), style: kText(15, FontWeight.w600, lh: 20)),
                    TextSpan(
                      text: tr('/ngày'),
                      style: kText(11, FontWeight.w300, color: AppColors.muted),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                [
                  item.province ?? tr(item.categoryName),
                  if (item.status == 'Rented') tr('Đang có người thuê'),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: kSub12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
