import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/item_service.dart';
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
  String _sort = 'newest';
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
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<Item>;
        _categories = results[1] as List<Category>;
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
    switch (_sort) {
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
              PopupMenuButton<String>(
                tooltip: 'Sắp xếp',
                initialValue: _sort,
                onSelected: (v) => setState(() => _sort = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'newest', child: Text('Mới đăng')),
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
