import 'dart:math';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
import '../services/rental_service.dart';
import '../services/view_history.dart';
import '../widgets/ui.dart';
import 'item_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = ItemService();
  List<Item> _items = [];
  List<Category> _categories = [];
  int? _parentId; // danh mục cha đang chọn, null = tất cả
  int? _childId; // danh mục con đang chọn trong danh mục cha
  String _search = '';
  String? _sort; // null = mặc định: khách "Được thuê nhiều nhất", đã đăng nhập "Dành cho bạn"
  Map<int, double> _categoryScore = {}; // điểm sở thích theo danh mục (từ lượt xem và đơn đã thuê)
  String _name = '';
  String? _userId;
  bool _loading = true;
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
      final results = await Future.wait([_service.getItems(), _service.getCategories()]);
      final auth = AuthService();
      _name = await auth.getFullName() ?? '';
      _userId = await auth.getUserId();
      final items = results[0] as List<Item>;
      final categories = results[1] as List<Category>;
      final scores = _userId == null ? <int, double>{} : await _buildCategoryScore(_userId!, items, categories);
      if (!mounted) return;
      setState(() {
        _items = items;
        _categories = categories;
        _categoryScore = scores;
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

  List<Category> get _children =>
      _parentId == null ? [] : _categories.where((c) => c.parentId == _parentId).toList();

  bool _matchesCategory(Item item) {
    if (_childId != null) return item.categoryId == _childId;
    if (_parentId == null) return true;
    if (item.categoryId == _parentId) return true;
    // Chọn danh mục cha thì hiện cả đồ thuộc các danh mục con của nó
    return _categories.any((c) => c.id == item.categoryId && c.parentId == _parentId);
  }

  List<Item> get _visibleItems {
    final keyword = _search.trim().toLowerCase();
    final list = _items
        .where(_matchesCategory)
        .where((i) =>
            keyword.isEmpty ||
            i.name.toLowerCase().contains(keyword) ||
            i.description.toLowerCase().contains(keyword))
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
      case 'priceAsc':
        list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      case 'priceDesc':
        list.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(scheme)),
              SliverToBoxAdapter(child: _categoryBar()),
              SliverToBoxAdapter(child: _sortTabs()),
              ..._body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_name.isEmpty ? 'Xin chào 👋' : 'Xin chào, ${_name.split(' ').last} 👋',
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          const Text('Hôm nay bạn muốn thuê gì?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm laptop, máy ảnh, lều...',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 8),
              // Sắp xếp theo giá; các kiểu sắp xếp chính nằm ở hàng tab dưới danh mục
              PopupMenuButton<String>(
                tooltip: 'Sắp xếp theo giá',
                initialValue: _effectiveSort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'priceAsc', child: Text('Giá thấp → cao')),
                  PopupMenuItem(value: 'priceDesc', child: Text('Giá cao → thấp')),
                ],
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Icon(Icons.tune_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoryBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip('Tất cả', _parentId == null, () => setState(() {
                    _parentId = null;
                    _childId = null;
                  })),
              for (final c in _parents)
                _chip(c.name, _parentId == c.id, () => setState(() {
                      _parentId = c.id;
                      _childId = null;
                    }), icon: ItemThumb.iconFor(c.name)),
            ],
          ),
        ),
        // Danh mục cha có con: hiện thêm hàng danh mục con
        if (_children.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip('Tất cả', _childId == null, () => setState(() => _childId = null), small: true),
                for (final c in _children)
                  _chip(c.name, _childId == c.id, () => setState(() => _childId = c.id), small: true),
              ],
            ),
          ),
      ],
    );
  }

  /// Hàng tab sắp xếp: Dành cho bạn (chỉ khi đã đăng nhập) / Được thuê nhiều nhất / Mới đăng.
  Widget _sortTabs() {
    final scheme = Theme.of(context).colorScheme;
    Widget tab(String value, String label) {
      final selected = _effectiveSort == value;
      return InkWell(
        onTap: () => setState(() => _sort = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              )),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          if (_userId != null) tab('forYou', 'Dành cho bạn'),
          tab('popular', 'Được thuê nhiều nhất'),
          tab('newest', 'Mới đăng'),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon, bool small = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: small ? VisualDensity.compact : null,
        onSelected: (_) => onTap(),
      ),
    );
  }

  List<Widget> _body() {
    if (_loading) return const [SliverFillRemaining(child: LoadingView())];
    if (_error != null) {
      return [SliverFillRemaining(child: ErrorView(message: _error!, onRetry: _load))];
    }
    final items = _visibleItems;
    if (items.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyView(
            icon: Icons.search_off_rounded,
            title: _items.isEmpty ? 'Chưa có đồ nào được đăng' : 'Không tìm thấy đồ phù hợp',
            subtitle: _items.isEmpty ? 'Hãy là người đầu tiên đăng đồ cho thuê!' : 'Thử từ khóa hoặc danh mục khác.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text('${items.length} món đồ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _itemCard(items[i]),
        ),
      ),
    ];
  }

  Widget _itemCard(Item item) {
    final scheme = Theme.of(context).colorScheme;
    final mine = item.ownerId == _userId;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: item.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ItemThumb(categoryName: item.categoryName, imageUrl: item.imageUrl, size: 96, radius: 10),
                  if (mine || item.status == 'Rented')
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: mine ? scheme.primary : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(mine ? 'Đồ của bạn' : 'Đang được thuê',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
                      const SizedBox(height: 4),
                      Text(item.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: formatVnd(item.pricePerDay),
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          TextSpan(text: ' /ngày', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                        ]),
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
